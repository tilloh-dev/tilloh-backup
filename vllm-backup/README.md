# vllm-backup — vLLM als Zweit-Engine (getestet, Stand 2026-09-09)

Setup im Stil von `llama.cpp/`: `cp config.env.example config.env`, dann
`bash install.sh` (venv + Modell-Download), `bash serve.sh` (OpenAI-Server auf
:8091). Läuft NUR in WSL (vLLM hat kein natives Windows); Modelle liegen auf
WSL-ext4 (`~/.local/share/vllm/models`), weil vLLM bei jedem Start ~19 GB
safetensors liest und /mnt/e (drvfs) dafür zu langsam ist.

## Messergebnis auf hermine (4090, WSL2, vLLM 0.28.0, Qwen3.8-27B W4A16-AutoRound)

| Achse | vLLM (stock) | llama.cpp Daily Driver ([Qwen3.8-27B] GSQ) |
|---|---|---|
| Decode (Prosa) | 46,1 t/s (sehr stabil) | 72–82 t/s |
| Verbatim-Rewrites | 46 t/s (kein ngram-Spec) | 243–453 t/s |
| Max. Kontext | **3.584** (!) | **262.144** |
| TTFT kurz | ~0,1 s | ~0,1–0,5 s |

Warum der Kontext kollabiert: W4A16-Weights sind 19 GB (GSQ: 11,3), WSL zeigt
der Karte nur 22,49 GiB, vLLM hält KV in bf16 (llama.cpp: q4_0) und reserviert
DeltaNet-State-Blöcke pro Sequenz (Default 256 → `--max-num-seqs 1` gesetzt,
das llama.cpp-`parallel = 1`-Äquivalent). fp8-KV würde ~verdoppeln, scheitert
aber am FlashInfer-JIT (nvcc 13.3 via pip vs. torch-CUDA 13.0 — Header-Konflikt;
Workaround im serve.sh: FLASH_ATTN-Backend, Sampler-Fallback).

Die kursierenden 114–126 t/s für dieses Modell auf 3090/4090 sind **gepatchte**
vLLM-Stacks (eigene Requants, MTP-Patches, die nach jedem vLLM-Upgrade neu
appliziert werden müssen) — dieselbe Kategorie wie llama.cpp-Vendor-Forks, die
dieses Repo per Policy ausschließt.

## Verdikt

Für Single-User-Agentik (Claude Code, lange Kontexte) auf DIESER Hardware ist
llama.cpp die richtige Engine. vLLM lohnt hier erst, wenn (a) viele parallele
Requests bedient werden sollen (seine eigentliche Stärke: PagedAttention-Batching,
~1.000 t/s aggregiert bei 64 Clients auf einer 3090), (b) ein natives
Linux-System die volle Karte sieht, oder (c) man die Patch-Pipeline pflegen will.
Details/Historie: `docs/inference-engines.md`.
