# comfyui-backup — image generation on the second GPU

ComfyUI as a long-running server on Gertrude's **RTX 3060**, next to the
llama.cpp router on the **7900 XTX**. Same shape as `llama.cpp/` and
`vllm-backup/`: config in a gitignored `config.env`, a model manifest, a
`serve.sh`, and a systemd user unit.

## Why the two engines cannot collide

Not by configuration — structurally. ComfyUI runs on PyTorch/**CUDA**, and the
AMD card is not a CUDA device at all; llama.cpp runs on **Vulkan** and is pinned
to `VULKAN0` = 7900 XTX. Neither can allocate on the other's card even by
mistake. The one shared resource is **system RAM**.

## Install

```sh
cd comfyui-backup
cp config.env.example config.env
cp models.example.list models.list
bash install.sh                         # ComfyUI + venv + pinned torch + GGUF node
bash download-models.sh --all           # ~16 GB
bash serve.sh                           # or install the unit below
```

`install.sh` ends with two checks that both have to pass, because each catches a
different half of a narrow version window (see `config.env.example`): torch must
see the GPU, and `import comfy_kitchen` must succeed.

## As a service

```sh
cp systemd/comfyui.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now comfyui.service
```

## Measured on Gertrude

RTX 3060 12 GB, driver 535.309.01, torch 2.7.1+cu126, qwen3vl_8b int8 encoder +
bf16 VAE. 1024×1024, 20 steps, euler/simple, cfg 2.5.

### `--lowvram` against `NORMAL_VRAM` (2026-09-24, Comfy-Org model)

| Mode | Time | VRAM peak | Headroom |
|---|---|---|---|
| **`--lowvram` (default)** | **183.6 s** | **9515 MiB** | 2773 MiB |
| `NORMAL_VRAM` | 201.7 s | 11411 MiB | 877 MiB |

**`--lowvram` is both faster and leaner here**, the opposite of what the name
suggests — it offloads, so it should cost time. It does not. The setting was
originally chosen to make the model fit at all; that reasoning was wrong (it
fits either way) but the conclusion held for a different, measured reason.

### Uncensored swap (2026-09-26)

The Comfy-Org model was replaced by `abenzerps`' uncensored build. Same format,
same size, native loader, no config change.

| Model | Run | Time | VRAM peak |
|---|---|---|---|
| Comfy-Org | cold | 186.6 s | 8871 MiB |
| Comfy-Org | warm | 183.6 s | 9515 MiB |
| uncensored | cold | 201.8 s | 8555 MiB |
| uncensored | warm | 171.6 s | 9195 MiB |

**No difference that survives the noise.** The spread *within* the uncensored
model is 30 s (171.6–201.8) and exceeds the gap *between* the models; the VRAM
ranges overlap. The swap is free.

This also corrects the `--lowvram` comparison above: the two Comfy-Org runs
happened to land 3 s apart, which made the box look far more repeatable than it
is. Treat single runs here as indicative only — the mode comparison stands on a
1.9 GB VRAM difference, not on its 18 s.

## Model choice: the GGUF route does not work for this model

`ComfyUI-GGUF` cannot load Qwen-Image-2.1. The unsloth GGUFs carry no
`general.architecture` field, so the loader falls back to guessing from tensor
names, and its `detect_arch` only knows flux, sd3, aura, hidream, cosmos, hyvid
and wan. There is no newer upstream commit — this is missing support, not a
stale checkout.

The native Comfy-Org safetensors are the better route anyway:

| | GGUF Q4_K_M | Comfy-Org int8 |
|---|---|---|
| size | 3.91 GB | 6.76 GB |
| loader | custom node | ComfyUI native |
| source | community requant | official |
| works | no | yes |

The GGUF node is still installed and harmless; other models may need it.

Since 2026-09-26 the model served is `abenzerps`' **uncensored** build in the
same int8 format. Note the two axes: the uncensored diffusion models are one
family, and `pottokao`'s "Heretic" **text encoders** — including
`qwen3vl_8b_int8_convrot_heretic.safetensors` in exactly this format — are
another. That such a family exists suggests part of the refusal behaviour sits
in the encoder rather than the diffusion model; only the model was swapped here.
Provenance caveat: these are community re-releases with no checksums against an
official source, and the repo bundles copies of the Comfy-Org encoder and VAE
(identical files, so they are not re-downloaded).

**Numbers quoted in blog posts did not survive contact**: "~11 GB for
Qwen-Image-2.1" is wrong at both ends — the full bf16 model is 13.25 GB and the
int8 build 6.76 GB — and the repo id `RealRebelAI/Qwen-Image-2.1-GGUF` does not
exist (the real one is lowercase with an underscore). Everything above was
measured on this box; anything that was not is marked as such.

## Reaching it from the Hermes agent

Hermes runs in a Docker container (`nousresearch/hermes-agent`) on the
`hermes_network` bridge, so **`127.0.0.1` from inside it is not the host**. Use
the bridge gateway — `172.20.0.1` on Gertrude — the same route Hermes already
uses for the llama.cpp router on `172.21.0.1:8081`. That is why `COMFY_HOST`
defaults to `0.0.0.0`.

UFW has `INPUT policy DROP`, so the container path needs an explicit rule even
though it never leaves the machine:

```sh
sudo ufw allow from 172.16.0.0/12 to any port 8188 proto tcp comment 'ComfyUI from Docker'
```

Hermes 0.15.1+ speaks ComfyUI natively through its `image_gen` tool, and the
`hermes-comfyui-local` plugin bundles a `qwen_image_2_1_txt2img` workflow, so no
OpenAI-style adapter is needed:

```yaml
image_gen:
  provider: comfyui
  comfyui:
    host: http://172.20.0.1:8188
    workflow: qwen_image_2_1_txt2img
    timeout: 600
```

`timeout: 600` matters — a generation takes ~184 s here, and the plugin default
would be tight for larger batches.

Gertrude runs Hermes **0.20.5** with `HERMES_HOME=/opt/data` mapped to
`~/hermes/data`, so config and plugins survive the container updates `wud`
triggers.
