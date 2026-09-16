# VG AI Art

Generate game art from text prompts inside the Visual Gasic IDE.

This is an **experimental** plugin. It calls free, hosted AI image services
over HTTPS — no local install, no GPU required. If the hosted services prove
unreliable or low-quality the plugin can simply be disabled or removed.

## Backends

| Backend | Setup | Cost | Commercial Use | Notes |
|---|---|---|---|---|
| **Pollinations** | none — works out of the box | free | yes (per provider ToS) | default; uses Flux Schnell. Anonymous, no key. |
| **Hugging Face Inference API** | paste API token in settings | free tier (rate-limited) | depends on selected model | better quality / model choice. |
| **Local / Remote A1111** | Settings → ⚙ → server picker | free (local) or pay-per-hour (cloud GPU) | yes | Advanced. Pick "Local — this computer" for an in-place install (~10 GB, GPU strongly recommended), or click **+ Add…** to register a cloud GPU you rent (RunPod / Vast.ai / ngrok / Cloudflare Tunnel). HTTP Basic auth supported per server. |

You can switch backends in the plugin's settings panel. Pollinations is the
default so the plugin works the moment it's enabled.

## Walk cycles in one click

The **Walk Strip 4f (Pollinations)** preset returns a single 1024×256
sprite-strip image and auto-splits it into four 32×32 frames — a complete
walk cycle from a free hosted backend in ~5 seconds, no GPU required and
no per-frame consistency loss. Just type a character description and
click Generate.

Multi-call animation presets (Walk Cycle 4f/8f, Idle Bob, Attack Swing)
exist for the Local / Remote A1111 backend, where ControlNet OpenPose
locks the pose per frame for tighter consistency at the cost of one API
call per frame.

## Usage

1. Enable plugin in **Plugin Settings**.
2. Click the **🎨 AI Art** button on the IDE toolbar (or open the right-dock panel).
3. Type a prompt, e.g. *"16-bit pixel art knight sprite, sword, blue tunic, white background"*.
4. Choose a preset (Sprite, Icon, Tile, Portrait, Free).
5. Click **Generate**. After a few seconds the result appears in the preview.
6. Click **Save to Project** to drop it into your project's `assets/ai_art/` folder.
   The path is announced on `VGAssetBus.asset_saved` so the file browser
   refreshes automatically.

## Pixelify post-pass

For pixel-art presets the plugin downscales the model output with
nearest-neighbor and optional palette quantization, producing crisp
sprite-sized PNGs regardless of the upstream model.

## Privacy

Prompts and the resulting images are sent to and processed by the selected
third-party provider. Read each provider's terms before sending anything
sensitive. The plugin never sends your project files anywhere — only the
prompt text you type.

## Disabling / removing

Disable in Plugin Settings, or delete this folder. No core VG files are
modified.
