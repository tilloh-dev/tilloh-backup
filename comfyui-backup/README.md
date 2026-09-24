# comfyui-backup — image generation on the second GPU

ComfyUI as a long-running server on Gertrude's **RTX 3060**, next to the
llama.cpp router on the **7900 XTX**. Same shape as `llama.cpp/` and
`vllm-backup/`: config in a gitignored `config.env`, a model manifest, a
`serve.sh`, and a systemd user unit.

## Why the two engines cannot collide

Not by configuration — structurally. ComfyUI runs on PyTorch/**CUDA**, and the
AMD card is not a CUDA device at all; llama.cpp runs on **Vulkan** and is pinned
to `VULKAN0` = 7900 XTX. Neither can allocate on the other's card even by
mistake. The one shared resource is **system RAM**, which `--lowvram` uses for
the text encoder.

## Install

```sh
cd comfyui-backup
cp config.env.example config.env        # adjust COMFY_DIR if you want
cp models.example.list models.list
bash install.sh                         # ComfyUI + venv + torch(cu121) + GGUF node
bash download-models.sh --all           # ~20 GB
bash serve.sh                           # or install the unit below
```

`install.sh` ends with a CUDA check and fails loudly if torch cannot see the
card — a CPU-only wheel sneaking in over the CUDA one is the classic failure
here, which is why torch is installed *before* `requirements.txt`.

## As a service

```sh
cp systemd/comfyui.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now comfyui.service
```

## Sizing, measured by others (2026-09)

Qwen-Image-2.1 needs ~24 GB in its fp8/int8 form and **~11.1 GB as a Q4 GGUF**,
which is why the GGUF build is the only one that fits a 12 GB card. Keep the
diffusion model on the GPU and let the text encoder live in system RAM — that
saves 9–17 GB of VRAM at almost no speed cost. Sources:
[Unsloth](https://unsloth.ai/docs/models/qwen-image-2.1),
[WillItRunAI](https://willitrunai.com/image-models/qwen-image),
[kombitz](https://www.kombitz.com/2026/09/20/how-to-use-qwen-image-2-1-gguf-in-comfyui/).

**Not yet measured on Gertrude** — no VRAM figure, no seconds-per-image, no
confirmation that Q4 plus a bf16 encoder actually stays under 12 GB in practice.
Fill this section in after the first real run; until then the numbers above are
other people's.

## Reaching it from the Hermes agent

Hermes runs in a Docker container (`nousresearch/hermes-agent`) on the
`hermes_network` bridge, so **`127.0.0.1` from inside it is not the host**. Use
the bridge gateway — `172.20.0.1` on Gertrude — which is the same route Hermes
already uses to reach the llama.cpp router on `172.21.0.1:8081`. That is why
`COMFY_HOST` defaults to `0.0.0.0` and not to loopback.

UFW on Gertrude allows 8081 from `192.168.1.0/24`, `172.21.0.0/24` and
`172.16.0.0/12`; port 8188 needs the same treatment before the container can
reach it.

Hermes 0.15.1+ ships native ComfyUI support through its `image_gen` tool, and
the `hermes-comfyui-local` plugin bundles a ready `qwen_image_2_1_txt2img`
workflow, so no OpenAI-style adapter is needed:

```yaml
image_gen:
  provider: comfyui
  comfyui:
    host: http://172.20.0.1:8188
    workflow: qwen_image_2_1_txt2img
    timeout: 600
```

Gertrude runs Hermes **0.20.5**, and `HERMES_HOME=/opt/data` maps to
`~/hermes/data` on the host — config and plugins therefore survive a container
update, which matters because `wud` watches the image for new releases.
