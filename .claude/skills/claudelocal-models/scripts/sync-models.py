#!/usr/bin/env python3
"""Sync the modelPicker rows in the claudelocal settings file with what a
llama.cpp router actually serves at /v1/models.

Rows that already exist keep their label, description and behavesAs verbatim --
those are hand-written and worth more than anything this script could generate.
New model IDs are appended with a description derived from the router's own
answer (ctx-size from the preset args, modalities from the architecture block).
IDs the router no longer serves are dropped, because a dead ID in the picker is
exactly the defect this script exists to prevent.

Stdlib only; no jq, no requests.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_BEHAVES_AS = "claude-sonnet-5"

REPO_ROOT = Path(__file__).resolve().parents[4]
DEFAULT_SETTINGS = REPO_ROOT / "claude-backup" / ".claude" / "settings.local.json"


def fetch_models(base_url: str, timeout: float) -> list[dict]:
    url = base_url.rstrip("/") + "/v1/models"
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            payload = json.load(response)
    except urllib.error.URLError as exc:
        raise SystemExit(f"error: cannot reach {url}: {exc.reason}") from exc
    except (TimeoutError, OSError) as exc:
        raise SystemExit(f"error: cannot reach {url}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"error: {url} did not answer with JSON: {exc}") from exc

    data = payload.get("data")
    if not isinstance(data, list) or not data:
        raise SystemExit(f"error: {url} returned no models")
    return data


def ctx_size(model: dict) -> int | None:
    """Read --ctx-size out of the preset args the router reports."""
    args = (model.get("status") or {}).get("args")
    if not isinstance(args, list):
        return None
    try:
        raw = args[args.index("--ctx-size") + 1]
    except (ValueError, IndexError):
        return None
    try:
        return int(raw)
    except (TypeError, ValueError):
        return None


def describe(model: dict) -> str:
    """Build a description from what the router reports, not from guesswork."""
    parts: list[str] = []

    ctx = ctx_size(model)
    if ctx is not None:
        parts.append(f"{ctx // 1024}k ctx" if ctx >= 1024 else f"{ctx} ctx")

    modalities = (model.get("architecture") or {}).get("input_modalities") or []
    extra = [m for m in modalities if m != "text"]
    if extra:
        parts.append("input: " + ", ".join(["text", *extra]))

    if model.get("source") == "cache":
        parts.append("HuggingFace cache entry, no preset")

    return ", ".join(parts) or "served by the llama.cpp router"


def load_settings(path: Path) -> dict:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise SystemExit(f"error: cannot read {path}: {exc}") from exc
    try:
        settings = json.loads(text)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"error: {path} is not valid JSON: {exc}") from exc
    if not isinstance(settings, dict):
        raise SystemExit(f"error: {path} must contain a JSON object")
    return settings


def base_url_from(settings: dict, path: Path) -> str:
    url = (settings.get("env") or {}).get("ANTHROPIC_BASE_URL")
    if not url:
        raise SystemExit(
            f"error: {path} has no env.ANTHROPIC_BASE_URL; pass --base-url instead"
        )
    return url


def with_model_picker(settings: dict, picker: dict) -> dict:
    """Return settings with modelPicker replaced, keeping the key order stable."""
    if "modelPicker" in settings:
        return {k: (picker if k == "modelPicker" else v) for k, v in settings.items()}

    out: dict = {}
    for key, value in settings.items():
        out[key] = value
        if key == "env":
            out["modelPicker"] = picker
    if "modelPicker" not in out:
        out["modelPicker"] = picker
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--settings",
        type=Path,
        default=DEFAULT_SETTINGS,
        help=f"settings file to update (default: {DEFAULT_SETTINGS})",
    )
    parser.add_argument(
        "--base-url",
        help="router base URL (default: env.ANTHROPIC_BASE_URL from the settings file)",
    )
    parser.add_argument(
        "--behaves-as",
        default=DEFAULT_BEHAVES_AS,
        help=f"behavesAs target for new rows (default: {DEFAULT_BEHAVES_AS})",
    )
    parser.add_argument(
        "--keep-unserved",
        action="store_true",
        help="keep rows whose model ID the router no longer serves",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        metavar="ID",
        help="model ID never to add as a new row (repeatable)",
    )
    parser.add_argument(
        "--presets-only",
        action="store_true",
        help="only add models the router serves from a preset, not HuggingFace "
        "cache entries pulled on demand",
    )
    parser.add_argument(
        "--timeout", type=float, default=15.0, help="HTTP timeout in seconds"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="report the diff, write nothing"
    )
    args = parser.parse_args()

    settings = load_settings(args.settings)
    base_url = args.base_url or base_url_from(settings, args.settings)

    models = fetch_models(base_url, args.timeout)
    served = {m["id"]: m for m in models if isinstance(m.get("id"), str)}
    if not served:
        raise SystemExit(f"error: {base_url} returned models without usable IDs")

    picker = settings.get("modelPicker")
    if not isinstance(picker, dict):
        picker = {"replaceBuiltInOptions": True, "options": []}
    old_rows = picker.get("options")
    if not isinstance(old_rows, list):
        old_rows = []

    kept: list[dict] = []
    dropped: list[str] = []
    seen: set[str] = set()

    for row in old_rows:
        if not isinstance(row, dict) or not isinstance(row.get("model"), str):
            continue
        model_id = row["model"]
        if model_id in seen:
            continue
        if model_id in served or args.keep_unserved:
            seen.add(model_id)
            kept.append(row)
        else:
            dropped.append(model_id)

    added: list[str] = []
    skipped: list[str] = []
    excluded = set(args.exclude)
    for model_id, model in served.items():
        if model_id in seen:
            continue
        if model_id in excluded:
            skipped.append(f"{model_id} (--exclude)")
            continue
        if args.presets_only and model.get("source") != "preset":
            skipped.append(f"{model_id} (--presets-only, source={model.get('source')})")
            continue
        seen.add(model_id)
        added.append(model_id)
        kept.append(
            {
                "model": model_id,
                "label": model_id,
                "description": describe(model),
                "behavesAs": args.behaves_as,
            }
        )

    picker = {**picker, "options": kept}
    picker.setdefault("replaceBuiltInOptions", True)
    updated = with_model_picker(settings, picker)

    changed = updated != settings
    print(f"router:   {base_url} -- {len(served)} model(s) served")
    print(f"settings: {args.settings}")
    for model_id in added:
        print(f"  + {model_id}")
    for model_id in dropped:
        print(f"  - {model_id} (no longer served)")
    for note in skipped:
        print(f"  ~ {note}")
    if not added and not dropped:
        print("  = picker already matches the router")

    env = updated.get("env") or {}
    warnings = 0
    for key in ("ANTHROPIC_MODEL", "ANTHROPIC_SMALL_FAST_MODEL"):
        value = env.get(key)
        if value and value not in served:
            warnings += 1
            print(f"  ! env.{key} = {value!r} is not served by the router")

    max_ctx = env.get("CLAUDE_CODE_MAX_CONTEXT_TOKENS")
    default_model = env.get("ANTHROPIC_MODEL")
    if max_ctx and default_model in served:
        model_ctx = ctx_size(served[default_model])
        try:
            wanted = int(max_ctx)
        except (TypeError, ValueError):
            wanted = None
        if model_ctx is not None and wanted is not None and wanted > model_ctx:
            warnings += 1
            print(
                f"  ! CLAUDE_CODE_MAX_CONTEXT_TOKENS = {wanted} exceeds the "
                f"{model_ctx} ctx of {default_model}"
            )

    if args.dry_run:
        print("dry run: nothing written")
        return 0

    if not changed:
        return 0

    args.settings.write_text(
        json.dumps(updated, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"written: {args.settings}")
    if warnings:
        print("resolve the ! lines above before using the file")
    return 0


if __name__ == "__main__":
    sys.exit(main())
