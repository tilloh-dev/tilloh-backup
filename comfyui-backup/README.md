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
bf16 VAE, 1024×1024 throughout.

### Lightning LoRA, and the encoder back on the GPU (2026-11-01)

Served since: Comfy-Org `qwen_image_2.1_int8_convrot` + LightX2V Lightning LoRA,
4 steps, cfg 1.0, euler/simple, AuraFlow shift 2.0 at 1 MP (`shift: auto`
since the 2 MP switch below), **no `--lowvram`**.

Shift 2.0 is not a guess. The LoRA's model card trains on sigmas
[1.0, 0.75, 0.5, 0.25] with dynamic exponential shifting (base 0.5 at 256
tokens, max 0.9 at 8192). At 1 MP that is mu ≈ 0.69, e^mu ≈ 2.0, and AuraFlow's
shift formula is the same transform, so euler/simple at 4 steps with shift 2.0
lands on the training schedule.

| Setup | Edit job (with source image) | Text-to-image | VRAM peak |
|---|---|---|---|
| before: UC model, 10 steps, cfg 2.5, `--lowvram` | 155.7 / 189.4 s | — | — |
| Lightning, `--lowvram` | 75.1 / 75.2 / 79.5 s | 33.8 / 34.1 s | — |
| **Lightning, `NORMAL_VRAM`** | **45.2 / 45.9 / 48.9 s** | **20.1 / 33.6 s** | **11465 MiB** |

Where the time went before: with `--lowvram` ComfyUI pins the text encoder to the
**CPU** (`text_encoder_device()` in `comfy/model_management.py`), and an edit
job runs it over the source image as well. That was ~70 s cold and ~48 s warm
— negligible next to 20 steps at cfg 2.5, but two thirds of a 4-step job. On the
GPU it takes a few seconds plus a swap: encoder in, diffusion model partially
out, and back. Text-to-image at 20.1 s is the case where the prompt was cached
and no swap happened.

This reverses the 2026-09-24 conclusion below. That measurement was right for
its workload and wrong for this one; the swap costs ~7 s and the CPU encoder
~48 s. Dynamic VRAM (the other way to put the encoder on the GPU) needs torch
≥ 2.8, which driver 535 rules out.

Log noise, not a leak: `lowvram patches` in "Unloaded partially" grows by 128
per job. ComfyUI resets the original weights before offloading and wipes the
patches on the next full load (`wipe_lowvram_weight`); only the counter is never
reset outside a full unpatch. Job times stay flat.

Hermes builds the graph in its own `image_gen/gertrude-bild` plugin
(`~/hermes/data/plugins/`), not the `hermes-comfyui-local` workflow mentioned
below; the Lightning defaults live there. `steps` in a profile's
`image_gen.gertrude-bild` block overrides them — six profiles had `steps: 10`.

### Native 2 MP instead of an upscaler (2026-11-01)

Qwen-Image **2.1** is trained up to ~4 MP — its model card lists 2048×2048 and
2752×1536 as the supported sizes. The plugin's old ~1 MP budget came from the
first Qwen-Image. It now generates at `megapixels: 2.0` (1824×1104 landscape,
1408×1408 square), with `shift: auto` computing the Lightning schedule's
dynamic shift per size (mu 0.5 → 0.9 over 256 → 8192 image tokens,
shift = e^mu: 2.0 at 1 MP, 2.45 at 2 MP). 2 MP sits right at the LoRA's
`max_image_seq_len` of 8192, so it is still inside its training range.

| Same prompts | 1 MP | **2 MP (default)** | 4 MP |
|---|---|---|---|
| Text-to-image | 20–34 s | **53–54 s** | OOM in KSampler |
| Edit (640² group photo source) | 44.8 s | **68.5 / 68.8 s** | not tried |

Faces at 2 MP were natural in both a six-person text-to-image group shot and
the six-person edit, with visibly more detail in hair, glasses and knitwear
than 1 MP — none of the upscaler's artefacts. The plugin caps the budget at
1472×1472, the largest size measured to fit on the edit path; 4 MP would need
more aggressive offloading (e.g. `--reserve-vram`) and was not pursued.

### Upscaler: built, then switched off (2026-11-01)

The plugin can append `ImageUpscaleWithModel` after the VAE decode (run at the
model's native 4x, scaled back to `upscale` with lanczos). It costs 8–10 s and
gives 2048 px at 7–10 MB. **It is off by default (`upscale: 1.0`)**, because it
ruins faces:

- On a user's edit job (640×640 group photo, six adults, faces ~40 px wide in
  the source), the same seed was re-run four ways. Lightning without upscaler
  gave natural faces; Lightning *and* the 20-step base model both got
  ink-outlined eyes and gapped, high-contrast teeth once 4x-UltraSharp ran.
  The upscaler, not the LoRA, was the cause.
- `4xNomosWebPhoto_RealPLKSR` (trained on degraded web photos) was milder but
  showed the same mouth artefacts.
- A text-to-image group shot (six people, full body) showed the same
  caricature effect, so it is not specific to small source images.
- Plain lanczos 2x is artefact-free and adds nothing but pixels.

Opt in per profile (`upscale: 2.0`) only for content without people, e.g.
signage. Anything above Telegram's 10 MB photo limit is not lost — Hermes'
Telegram adapter retries a rejected `send_photo` as a document (50 MB).

A real resolution gain for faces would need a second diffusion pass on the
upscaled image (hires fix), not a GAN upscaler. Not built.

### `--lowvram` against `NORMAL_VRAM` (2026-09-24, Comfy-Org model, superseded)

20 steps, euler/simple, cfg 2.5.

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
