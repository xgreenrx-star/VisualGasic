@tool
## VG AI Art — generate game sprites/icons/tiles from text prompts using
## free hosted AI image services.
##
## See README.md in this folder for details. The plugin is intentionally
## experimental: if it doesn't pan out, disabling or deleting this folder
## removes it cleanly with no core changes required.
extends "res://addons/visual_gasic/vg_plugin_base.gd"

const _Pollinations := preload("res://addons/visual_gasic/plugins/vgaiart/backends/pollinations.gd")
const _HuggingFace := preload("res://addons/visual_gasic/plugins/vgaiart/backends/huggingface.gd")
const _LocalA1111 := preload("res://addons/visual_gasic/plugins/vgaiart/backends/local_a1111.gd")
const _Pixelify := preload("res://addons/visual_gasic/plugins/vgaiart/pixelify.gd")
const _PoseRenderer := preload("res://addons/visual_gasic/plugins/vgaiart/pose_renderer.gd")

const _AssetBus := preload("res://addons/visual_gasic/vg_asset_bus.gd")

const _SETTINGS_BACKEND := "vg/ai_art/backend"
const _SETTINGS_HF_TOKEN := "vg/ai_art/huggingface_token"
const _SETTINGS_HF_MODEL := "vg/ai_art/huggingface_model"
const _SETTINGS_A1111_URL := "vg/ai_art/a1111_url"
# Saved cloud/LAN A1111 servers — JSON array of {name,url,user,pass}.
const _SETTINGS_A1111_SERVERS := "vg/ai_art/a1111_servers"
const _SETTINGS_A1111_ACTIVE := "vg/ai_art/a1111_active"
const _SETTINGS_LAST_PROMPT := "vg/ai_art/last_prompt"
const _SETTINGS_USE_CONTROLNET := "vg/ai_art/use_controlnet"
const _SETTINGS_REMOVE_BG := "vg/ai_art/remove_background"
# Per-preset prompt-default overrides are stored under
# "vg/ai_art/preset_overrides/<preset name>/{suffix,negative}".
const _SETTINGS_PRESET_OVERRIDE_ROOT := "vg/ai_art/preset_overrides"

# Built-in server entries (always present in the dropdown).
const _A1111_LOCAL_NAME := "Local — this computer"
const _A1111_LOCAL_URL := "http://127.0.0.1:7860"


# ─── Skeleton keypoints for animation presets ────────────────────
#
# 18-joint OpenPose body model. Each entry is a Vector2 in normalized
# 0..1 image space (x right, y down). Vector2(-1,-1) hides a joint.
#
# These are side-view stick figures facing right. For pixel-art sprites
# the OpenPose ControlNet model only needs roughly correct pose; exact
# proportions don't matter much.
#
# Indices: 0 nose, 1 neck,
#   2 r_shoulder, 3 r_elbow, 4 r_wrist,
#   5 l_shoulder, 6 l_elbow, 7 l_wrist,
#   8 r_hip, 9 r_knee, 10 r_ankle,
#   11 l_hip, 12 l_knee, 13 l_ankle,
#   14 r_eye, 15 l_eye, 16 r_ear, 17 l_ear

# Hidden joints constant for readability.
const _HIDE := Vector2(-1, -1)

# Walk cycle 4-frame: contact / pass / contact-mirror / pass.
# Frame 0: right leg back, left leg forward, right arm forward, left arm back.
const _WALK_4F := [
	# F0 — contact pose, R leg back, L leg forward
	[Vector2(0.55, 0.12), Vector2(0.50, 0.22),
	 Vector2(0.50, 0.24), Vector2(0.54, 0.38), Vector2(0.58, 0.50),
	 Vector2(0.48, 0.25), Vector2(0.44, 0.38), Vector2(0.40, 0.50),
	 Vector2(0.50, 0.55), Vector2(0.46, 0.74), Vector2(0.40, 0.95),
	 Vector2(0.50, 0.55), Vector2(0.54, 0.74), Vector2(0.60, 0.95),
	 Vector2(0.56, 0.10), _HIDE, Vector2(0.52, 0.11), _HIDE],
	# F1 — passing pose, legs together, arms low
	[Vector2(0.55, 0.12), Vector2(0.50, 0.22),
	 Vector2(0.50, 0.24), Vector2(0.50, 0.38), Vector2(0.50, 0.50),
	 Vector2(0.48, 0.25), Vector2(0.48, 0.38), Vector2(0.48, 0.50),
	 Vector2(0.50, 0.55), Vector2(0.50, 0.74), Vector2(0.50, 0.95),
	 Vector2(0.50, 0.55), Vector2(0.50, 0.74), Vector2(0.50, 0.95),
	 Vector2(0.56, 0.10), _HIDE, Vector2(0.52, 0.11), _HIDE],
	# F2 — contact mirror, L leg back, R leg forward
	[Vector2(0.55, 0.12), Vector2(0.50, 0.22),
	 Vector2(0.50, 0.24), Vector2(0.46, 0.38), Vector2(0.42, 0.50),
	 Vector2(0.48, 0.25), Vector2(0.52, 0.38), Vector2(0.56, 0.50),
	 Vector2(0.50, 0.55), Vector2(0.54, 0.74), Vector2(0.60, 0.95),
	 Vector2(0.50, 0.55), Vector2(0.46, 0.74), Vector2(0.40, 0.95),
	 Vector2(0.56, 0.10), _HIDE, Vector2(0.52, 0.11), _HIDE],
	# F3 — passing pose (same as F1)
	[Vector2(0.55, 0.12), Vector2(0.50, 0.22),
	 Vector2(0.50, 0.24), Vector2(0.50, 0.38), Vector2(0.50, 0.50),
	 Vector2(0.48, 0.25), Vector2(0.48, 0.38), Vector2(0.48, 0.50),
	 Vector2(0.50, 0.55), Vector2(0.50, 0.74), Vector2(0.50, 0.95),
	 Vector2(0.50, 0.55), Vector2(0.50, 0.74), Vector2(0.50, 0.95),
	 Vector2(0.56, 0.10), _HIDE, Vector2(0.52, 0.11), _HIDE],
]

# Walk cycle 8-frame: full contact-rise-pass-rise on each side.
const _WALK_8F := [
	# F0 contact (R back, L fwd)
	[Vector2(0.55,0.12), Vector2(0.50,0.22),
	 Vector2(0.50,0.24), Vector2(0.54,0.38), Vector2(0.58,0.50),
	 Vector2(0.48,0.25), Vector2(0.44,0.38), Vector2(0.40,0.50),
	 Vector2(0.50,0.55), Vector2(0.46,0.74), Vector2(0.40,0.95),
	 Vector2(0.50,0.55), Vector2(0.54,0.74), Vector2(0.60,0.95),
	 Vector2(0.56,0.10), _HIDE, Vector2(0.52,0.11), _HIDE],
	# F1 down (lowest, both feet planted briefly, body sinks)
	[Vector2(0.55,0.14), Vector2(0.50,0.24),
	 Vector2(0.50,0.26), Vector2(0.53,0.40), Vector2(0.56,0.52),
	 Vector2(0.48,0.27), Vector2(0.45,0.40), Vector2(0.42,0.52),
	 Vector2(0.50,0.57), Vector2(0.48,0.76), Vector2(0.45,0.97),
	 Vector2(0.50,0.57), Vector2(0.52,0.76), Vector2(0.55,0.97),
	 Vector2(0.56,0.12), _HIDE, Vector2(0.52,0.13), _HIDE],
	# F2 passing (legs together, body up)
	[Vector2(0.55,0.10), Vector2(0.50,0.20),
	 Vector2(0.50,0.22), Vector2(0.50,0.36), Vector2(0.50,0.48),
	 Vector2(0.48,0.23), Vector2(0.48,0.36), Vector2(0.48,0.48),
	 Vector2(0.50,0.53), Vector2(0.50,0.72), Vector2(0.50,0.93),
	 Vector2(0.50,0.53), Vector2(0.50,0.72), Vector2(0.50,0.93),
	 Vector2(0.56,0.08), _HIDE, Vector2(0.52,0.09), _HIDE],
	# F3 high-point (lifting next leg)
	[Vector2(0.55,0.10), Vector2(0.50,0.20),
	 Vector2(0.50,0.22), Vector2(0.48,0.36), Vector2(0.46,0.48),
	 Vector2(0.48,0.23), Vector2(0.50,0.36), Vector2(0.52,0.48),
	 Vector2(0.50,0.53), Vector2(0.52,0.70), Vector2(0.55,0.90),
	 Vector2(0.50,0.53), Vector2(0.46,0.68), Vector2(0.44,0.85),
	 Vector2(0.56,0.08), _HIDE, Vector2(0.52,0.09), _HIDE],
	# F4 contact mirror (L back, R fwd)
	[Vector2(0.55,0.12), Vector2(0.50,0.22),
	 Vector2(0.50,0.24), Vector2(0.46,0.38), Vector2(0.42,0.50),
	 Vector2(0.48,0.25), Vector2(0.52,0.38), Vector2(0.56,0.50),
	 Vector2(0.50,0.55), Vector2(0.54,0.74), Vector2(0.60,0.95),
	 Vector2(0.50,0.55), Vector2(0.46,0.74), Vector2(0.40,0.95),
	 Vector2(0.56,0.10), _HIDE, Vector2(0.52,0.11), _HIDE],
	# F5 down (mirror of F1)
	[Vector2(0.55,0.14), Vector2(0.50,0.24),
	 Vector2(0.50,0.26), Vector2(0.45,0.40), Vector2(0.42,0.52),
	 Vector2(0.48,0.27), Vector2(0.53,0.40), Vector2(0.56,0.52),
	 Vector2(0.50,0.57), Vector2(0.52,0.76), Vector2(0.55,0.97),
	 Vector2(0.50,0.57), Vector2(0.48,0.76), Vector2(0.45,0.97),
	 Vector2(0.56,0.12), _HIDE, Vector2(0.52,0.13), _HIDE],
	# F6 passing (same as F2)
	[Vector2(0.55,0.10), Vector2(0.50,0.20),
	 Vector2(0.50,0.22), Vector2(0.50,0.36), Vector2(0.50,0.48),
	 Vector2(0.48,0.23), Vector2(0.48,0.36), Vector2(0.48,0.48),
	 Vector2(0.50,0.53), Vector2(0.50,0.72), Vector2(0.50,0.93),
	 Vector2(0.50,0.53), Vector2(0.50,0.72), Vector2(0.50,0.93),
	 Vector2(0.56,0.08), _HIDE, Vector2(0.52,0.09), _HIDE],
	# F7 high-point mirror
	[Vector2(0.55,0.10), Vector2(0.50,0.20),
	 Vector2(0.50,0.22), Vector2(0.50,0.36), Vector2(0.52,0.48),
	 Vector2(0.48,0.23), Vector2(0.48,0.36), Vector2(0.46,0.48),
	 Vector2(0.50,0.53), Vector2(0.46,0.68), Vector2(0.44,0.85),
	 Vector2(0.50,0.53), Vector2(0.52,0.70), Vector2(0.55,0.90),
	 Vector2(0.56,0.08), _HIDE, Vector2(0.52,0.09), _HIDE],
]

# Idle bob: gentle vertical breathing.
const _IDLE_4F := [
	# F0 neutral
	[Vector2(0.55,0.12), Vector2(0.50,0.22),
	 Vector2(0.50,0.24), Vector2(0.50,0.38), Vector2(0.50,0.50),
	 Vector2(0.48,0.25), Vector2(0.48,0.38), Vector2(0.48,0.50),
	 Vector2(0.50,0.55), Vector2(0.50,0.74), Vector2(0.50,0.95),
	 Vector2(0.50,0.55), Vector2(0.50,0.74), Vector2(0.50,0.95),
	 Vector2(0.56,0.10), _HIDE, Vector2(0.52,0.11), _HIDE],
	# F1 inhale (head/torso slightly up)
	[Vector2(0.55,0.10), Vector2(0.50,0.20),
	 Vector2(0.50,0.22), Vector2(0.50,0.37), Vector2(0.50,0.49),
	 Vector2(0.48,0.23), Vector2(0.48,0.37), Vector2(0.48,0.49),
	 Vector2(0.50,0.54), Vector2(0.50,0.74), Vector2(0.50,0.95),
	 Vector2(0.50,0.54), Vector2(0.50,0.74), Vector2(0.50,0.95),
	 Vector2(0.56,0.08), _HIDE, Vector2(0.52,0.09), _HIDE],
	# F2 neutral
	[Vector2(0.55,0.12), Vector2(0.50,0.22),
	 Vector2(0.50,0.24), Vector2(0.50,0.38), Vector2(0.50,0.50),
	 Vector2(0.48,0.25), Vector2(0.48,0.38), Vector2(0.48,0.50),
	 Vector2(0.50,0.55), Vector2(0.50,0.74), Vector2(0.50,0.95),
	 Vector2(0.50,0.55), Vector2(0.50,0.74), Vector2(0.50,0.95),
	 Vector2(0.56,0.10), _HIDE, Vector2(0.52,0.11), _HIDE],
	# F3 exhale (sink slightly)
	[Vector2(0.55,0.13), Vector2(0.50,0.23),
	 Vector2(0.50,0.25), Vector2(0.50,0.39), Vector2(0.50,0.51),
	 Vector2(0.48,0.26), Vector2(0.48,0.39), Vector2(0.48,0.51),
	 Vector2(0.50,0.56), Vector2(0.50,0.75), Vector2(0.50,0.96),
	 Vector2(0.50,0.56), Vector2(0.50,0.75), Vector2(0.50,0.96),
	 Vector2(0.56,0.11), _HIDE, Vector2(0.52,0.12), _HIDE],
]

# Attack swing 4f: ready / overhead / strike / recover.
const _ATTACK_4F := [
	# F0 ready stance: weapon back behind shoulder
	[Vector2(0.55,0.14), Vector2(0.50,0.24),
	 Vector2(0.50,0.26), Vector2(0.40,0.30), Vector2(0.30,0.20),  # R arm cocked back
	 Vector2(0.48,0.27), Vector2(0.46,0.40), Vector2(0.45,0.52),
	 Vector2(0.50,0.57), Vector2(0.46,0.76), Vector2(0.40,0.95),
	 Vector2(0.50,0.57), Vector2(0.54,0.76), Vector2(0.60,0.95),
	 Vector2(0.56,0.12), _HIDE, Vector2(0.52,0.13), _HIDE],
	# F1 wind-up: weapon overhead
	[Vector2(0.55,0.10), Vector2(0.50,0.20),
	 Vector2(0.50,0.22), Vector2(0.52,0.10), Vector2(0.55,0.00),  # R arm straight up
	 Vector2(0.48,0.23), Vector2(0.46,0.36), Vector2(0.45,0.48),
	 Vector2(0.50,0.55), Vector2(0.50,0.74), Vector2(0.50,0.95),
	 Vector2(0.50,0.55), Vector2(0.50,0.74), Vector2(0.50,0.95),
	 Vector2(0.56,0.08), _HIDE, Vector2(0.52,0.09), _HIDE],
	# F2 strike: weapon forward, body forward-leaning
	[Vector2(0.60,0.14), Vector2(0.55,0.24),
	 Vector2(0.55,0.26), Vector2(0.70,0.30), Vector2(0.85,0.32),  # R arm extended fwd
	 Vector2(0.53,0.27), Vector2(0.50,0.40), Vector2(0.48,0.52),
	 Vector2(0.55,0.57), Vector2(0.62,0.76), Vector2(0.70,0.95),
	 Vector2(0.55,0.57), Vector2(0.50,0.76), Vector2(0.45,0.95),
	 Vector2(0.61,0.12), _HIDE, Vector2(0.57,0.13), _HIDE],
	# F3 recover: weapon lowered
	[Vector2(0.55,0.14), Vector2(0.50,0.24),
	 Vector2(0.50,0.26), Vector2(0.55,0.42), Vector2(0.62,0.55),  # R arm down/fwd
	 Vector2(0.48,0.27), Vector2(0.45,0.40), Vector2(0.43,0.52),
	 Vector2(0.50,0.57), Vector2(0.50,0.76), Vector2(0.50,0.95),
	 Vector2(0.50,0.57), Vector2(0.50,0.76), Vector2(0.50,0.95),
	 Vector2(0.56,0.12), _HIDE, Vector2(0.52,0.13), _HIDE],
]

# Preset name → params used to populate the prompt textarea and post-pass.
const _PRESETS := {
	"Sprite (32×32)": {
		"suffix": ", pixel art sprite, 32x32, clean outlines, plain white background, side view",
		"negative": "blurry, photograph, 3d, gradient, signature, watermark",
		"gen_w": 512, "gen_h": 512,
		"out_w": 32, "out_h": 32,
		"palette_steps": 6,
		"alpha_key": Color.WHITE, "alpha_key_tolerance": 0.18,
	},
	"Sprite (64×64)": {
		"suffix": ", pixel art sprite, 64x64, clean outlines, plain white background",
		"negative": "blurry, photograph, 3d, gradient, signature, watermark",
		"gen_w": 768, "gen_h": 768,
		"out_w": 64, "out_h": 64,
		"palette_steps": 8,
		"alpha_key": Color.WHITE, "alpha_key_tolerance": 0.18,
	},
	"Icon (32×32)": {
		"suffix": ", pixel art icon, centered, plain white background, simple, bold colors",
		"negative": "blurry, photograph, complex, watermark",
		"gen_w": 512, "gen_h": 512,
		"out_w": 32, "out_h": 32,
		"palette_steps": 6,
		"alpha_key": Color.WHITE, "alpha_key_tolerance": 0.18,
	},
	"Tile (32×32)": {
		"suffix": ", seamless tileable texture, top-down 2d game tile",
		"negative": "characters, objects, text, watermark, frame, border",
		"gen_w": 512, "gen_h": 512,
		"out_w": 32, "out_h": 32,
		"palette_steps": 8,
		"alpha_key": Color(0,0,0,0), "alpha_key_tolerance": 0.0,
	},
	"Portrait (256×256)": {
		"suffix": ", pixel art character portrait, head and shoulders, plain background",
		"negative": "blurry, photograph, watermark",
		"gen_w": 768, "gen_h": 768,
		"out_w": 256, "out_h": 256,
		"palette_steps": 0,
		"alpha_key": Color(0,0,0,0), "alpha_key_tolerance": 0.0,
	},
	"Free (no post-pass)": {
		"suffix": "",
		"negative": "",
		"gen_w": 768, "gen_h": 768,
		"out_w": 0, "out_h": 0,  # 0 = keep original size
		"palette_steps": 0,
		"alpha_key": Color(0,0,0,0), "alpha_key_tolerance": 0.0,
	},
	# Animation presets. `frame_prompts` holds the per-frame variant text
	# appended after the user prompt + suffix. `frames` auto-fills the spin.
	# `lock_seed=true` shares one seed across frames for better coherence
	# (otherwise each frame is essentially a fresh sample).
	"Walk Cycle 4f (32×32)": {
		"suffix": ", pixel art sprite, 32x32, side view, plain white background, full body, clean outlines",
		"negative": "blurry, photograph, 3d, gradient, signature, watermark, multiple characters",
		"gen_w": 512, "gen_h": 512,
		"out_w": 32, "out_h": 32,
		"palette_steps": 6,
		"alpha_key": Color.WHITE, "alpha_key_tolerance": 0.18,
		"frames": 4, "lock_seed": true,
		"frame_prompts": [
			", standing pose, legs together",
			", walking pose, left leg forward",
			", standing pose, legs together",
			", walking pose, right leg forward",
		],
		"pose_frames": _WALK_4F,
	},
	"Walk Cycle 8f (32×32)": {
		"suffix": ", pixel art sprite, 32x32, side view, plain white background, full body, clean outlines",
		"negative": "blurry, photograph, 3d, gradient, signature, watermark, multiple characters",
		"gen_w": 512, "gen_h": 512,
		"out_w": 32, "out_h": 32,
		"palette_steps": 6,
		"alpha_key": Color.WHITE, "alpha_key_tolerance": 0.18,
		"frames": 8, "lock_seed": true,
		"frame_prompts": [
			", standing neutral, legs together",
			", left leg lifting, knee bent",
			", left leg forward, mid stride",
			", left foot planted, right leg lifting",
			", standing neutral, legs together",
			", right leg lifting, knee bent",
			", right leg forward, mid stride",
			", right foot planted, left leg lifting",
		],
		"pose_frames": _WALK_8F,
	},
	"Idle Bob 4f (32×32)": {
		"suffix": ", pixel art sprite, 32x32, side view, plain white background, full body",
		"negative": "blurry, photograph, 3d, gradient, signature, watermark, multiple characters",
		"gen_w": 512, "gen_h": 512,
		"out_w": 32, "out_h": 32,
		"palette_steps": 6,
		"alpha_key": Color.WHITE, "alpha_key_tolerance": 0.18,
		"frames": 4, "lock_seed": true,
		"frame_prompts": [
			", relaxed standing pose",
			", relaxed standing pose, breathing in, slightly taller",
			", relaxed standing pose",
			", relaxed standing pose, breathing out, slightly shorter",
		],
		"pose_frames": _IDLE_4F,
	},
	"Attack Swing 4f (32×32)": {
		"suffix": ", pixel art sprite, 32x32, side view, plain white background, full body, clean outlines, sword",
		"negative": "blurry, photograph, 3d, gradient, signature, watermark, multiple characters",
		"gen_w": 512, "gen_h": 512,
		"out_w": 32, "out_h": 32,
		"palette_steps": 6,
		"alpha_key": Color.WHITE, "alpha_key_tolerance": 0.18,
		"frames": 4, "lock_seed": true,
		"frame_prompts": [
			", ready stance, sword held back",
			", swinging sword overhead, mid arc",
			", sword swung forward, follow through",
			", recovering, sword lowered",
		],
		"pose_frames": _ATTACK_4F,
	},
	# Pollinations-friendly single-call sprite strip. Asks the backend for
	# ONE wide image containing all 4 walk-cycle frames laid out left-to-right
	# on a uniform background, then auto-splits + pixelifies each. No
	# ControlNet, no per-frame seed gymnastics — works on any backend that
	# returns an image, including hosted free ones (Pollinations, HF).
	# Best novice path: pick this, type a character description, click Go.
	"Walk Strip 4f (Pollinations)": {
		"suffix": ", 4-frame walk cycle sprite strip, side view, identical character in 4 poses left to right, pixel art, plain white background, full body, clean outlines",
		"negative": "blurry, photograph, 3d, gradient, signature, watermark, multiple characters, different characters, varying styles",
		"gen_w": 1024, "gen_h": 256,
		"out_w": 32, "out_h": 32,
		"palette_steps": 6,
		"alpha_key": Color.WHITE, "alpha_key_tolerance": 0.18,
		"frames": 1, "lock_seed": false,
		"strip_count": 4,
	},
}

# UI nodes
var _backend_dd: OptionButton
var _preset_dd: OptionButton
var _prompt_edit: TextEdit
var _negative_edit: LineEdit
var _seed_spin: SpinBox
var _frames_spin: SpinBox
var _layout_dd: OptionButton
var _controlnet_check: CheckBox
var _remove_bg_check: CheckBox = null
var _defaults_btn: Button = null
var _generate_btn: Button
var _save_btn: Button
var _settings_btn: Button
var _status_label: Label
var _preview_rect: TextureRect
var _busy_indicator: Label
var _busy_box: VBoxContainer = null
var _busy_status: Label = null
var _busy_tip: Label = null
var _busy_anim_timer: Timer = null
var _busy_status_text: String = ""
var _busy_spin_idx: int = 0
var _busy_started_us: int = 0
var _busy_tip_idx: int = 0
var _busy_tip_next_change_s: float = 0.0
const _BUSY_SPIN_FRAMES := ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
const _BUSY_TIPS := [
	"Hang in there — CPU rendering is slow but steady.",
	"Each diffusion step takes ~15–20 s on CPU.",
	"Tip: GPUs run this 50–100× faster.",
	"Keeping the seed locked across frames for consistency.",
	"ControlNet pose-locks each frame to the skeleton.",
	"Almost there… image is being denoised.",
	"Take a break — this can take a few minutes.",
	"Tip: lower 'Frames' to test prompts faster.",
]
var _play_btn: Button
var _fps_spin: SpinBox
var _anim_timer: Timer = null
var _anim_frame_idx: int = 0
var _anim_full_tex: ImageTexture = null  # the full sheet texture (for stop)

# Backends
var _backends: Array = []
var _current_backend = null

# Last generated image (post-pass already applied; for sheets this is
# the composed sheet, not an individual frame).
var _last_image: Image = null
var _last_preset_name: String = ""
var _last_frame_count: int = 1
var _last_frame_w: int = 0
var _last_frame_h: int = 0

# Multi-frame (sheet) generation state.
var _frames_total: int = 1
var _frames_done: int = 0
var _frames_collected: Array = []  # Array[Image]
var _frame_seed_base: int = 0
var _frame_preset: Dictionary = {}
var _frame_params_tmpl: Dictionary = {}
var _frame_layout: String = "row"  # "row" or "grid"
var _frame_ok_cb: Callable = Callable()
var _frame_err_cb: Callable = Callable()

# UI build state
var _settings_panel: PopupPanel = null


# ─── VG plugin metadata ──────────────────────────────────────────

func get_plugin_name() -> String:
	return "AI Art"

func get_toolbar_icon() -> String:
	return "🎨"

func get_toolbar_color() -> Color:
	return Color(0.40, 0.18, 0.45)

func get_toolbar_tooltip() -> String:
	return "Generate game art from text prompts (experimental)."


# ─── UI ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	_backends = [_Pollinations.new(), _HuggingFace.new(), _LocalA1111.new()]
	_load_settings()

	# Solid dark backdrop behind the controls.
	var bg := PanelContainer.new()
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.13, 0.13, 0.15)
	bg.add_theme_stylebox_override("panel", bg_style)
	_view.add_child(bg)

	var root := MarginContainer.new()
	root.add_theme_constant_override("margin_left", 8)
	root.add_theme_constant_override("margin_right", 8)
	root.add_theme_constant_override("margin_top", 8)
	root.add_theme_constant_override("margin_bottom", 8)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg.add_child(root)

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 360
	root.add_child(split)

	# ── Left: controls ───────────────────────────────────────────
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 6)
	split.add_child(controls)

	var title := Label.new()
	title.text = "🎨  AI Art (experimental)"
	title.add_theme_font_size_override("font_size", 16)
	controls.add_child(title)

	var hint := Label.new()
	hint.text = "No setup needed — type a prompt and click Generate. Pollinations is free, no login, no GPU."
	hint.modulate = Color(0.7, 0.7, 0.7)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	controls.add_child(hint)

	controls.add_child(HSeparator.new())

	# Backend row
	var backend_row := HBoxContainer.new()
	controls.add_child(backend_row)
	var bl := Label.new(); bl.text = "Backend:"; bl.custom_minimum_size = Vector2(80, 0)
	backend_row.add_child(bl)
	_backend_dd = OptionButton.new()
	_backend_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for b in _backends:
		_backend_dd.add_item(b.get_display_name())
	_backend_dd.item_selected.connect(_on_backend_changed)
	backend_row.add_child(_backend_dd)
	_settings_btn = Button.new()
	_settings_btn.text = "⚙"
	_settings_btn.tooltip_text = "Backend settings (API keys, models)"
	_settings_btn.pressed.connect(_show_settings_dialog)
	backend_row.add_child(_settings_btn)

	# Preset row
	var preset_row := HBoxContainer.new()
	controls.add_child(preset_row)
	var pl := Label.new(); pl.text = "Preset:"; pl.custom_minimum_size = Vector2(80, 0)
	preset_row.add_child(pl)
	_preset_dd = OptionButton.new()
	_preset_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for name in _PRESETS.keys():
		_preset_dd.add_item(name)
	_preset_dd.item_selected.connect(_on_preset_changed)
	preset_row.add_child(_preset_dd)
	# Per-preset defaults editor (suffix/negative). Hidden behind a gear so
	# novices never have to think about it, but power users can tweak.
	_defaults_btn = Button.new()
	_defaults_btn.text = "⚙"
	_defaults_btn.tooltip_text = "Edit the default style/avoid prompt for this preset (saved per project)."
	_defaults_btn.pressed.connect(_open_preset_defaults_dialog)
	preset_row.add_child(_defaults_btn)

	# Prompt
	var prompt_label := Label.new()
	prompt_label.text = "Prompt:"
	controls.add_child(prompt_label)
	_prompt_edit = TextEdit.new()
	_prompt_edit.custom_minimum_size = Vector2(0, 100)
	_prompt_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_edit.placeholder_text = "e.g. a brave knight with blue tunic and silver sword"
	_prompt_edit.text = _load_setting(_SETTINGS_LAST_PROMPT, "")
	controls.add_child(_prompt_edit)

	# Negative prompt
	var neg_row := HBoxContainer.new()
	controls.add_child(neg_row)
	var nl := Label.new(); nl.text = "Avoid:"; nl.custom_minimum_size = Vector2(80, 0)
	neg_row.add_child(nl)
	_negative_edit = LineEdit.new()
	_negative_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_negative_edit.placeholder_text = "things to avoid (optional)"
	neg_row.add_child(_negative_edit)

	# Seed
	var seed_row := HBoxContainer.new()
	controls.add_child(seed_row)
	var sl := Label.new(); sl.text = "Seed:"; sl.custom_minimum_size = Vector2(80, 0)
	seed_row.add_child(sl)
	_seed_spin = SpinBox.new()
	_seed_spin.min_value = -1
	_seed_spin.max_value = 2147483647
	_seed_spin.value = -1
	_seed_spin.tooltip_text = "-1 = random each time"
	seed_row.add_child(_seed_spin)
	var rand_btn := Button.new()
	rand_btn.text = "🎲"
	rand_btn.tooltip_text = "Pick a random seed"
	rand_btn.pressed.connect(func(): _seed_spin.value = randi() & 0x7fffffff)
	seed_row.add_child(rand_btn)

	# Frames + layout (tile sheet)
	var sheet_row := HBoxContainer.new()
	controls.add_child(sheet_row)
	var fl := Label.new(); fl.text = "Frames:"; fl.custom_minimum_size = Vector2(80, 0)
	sheet_row.add_child(fl)
	_frames_spin = SpinBox.new()
	_frames_spin.min_value = 1
	_frames_spin.max_value = 16
	_frames_spin.value = 1
	_frames_spin.tooltip_text = "Number of frames (1 = single image, >1 = tile sheet). Free models have weak temporal coherence — best for tile/icon variants."
	sheet_row.add_child(_frames_spin)
	var layout_lbl := Label.new(); layout_lbl.text = "Layout:"
	sheet_row.add_child(layout_lbl)
	_layout_dd = OptionButton.new()
	_layout_dd.add_item("Row")
	_layout_dd.add_item("Grid")
	_layout_dd.tooltip_text = "Row: Nx1 strip. Grid: roughly square layout."
	sheet_row.add_child(_layout_dd)

	# ControlNet OpenPose toggle (animation presets only).
	var cn_row := HBoxContainer.new()
	controls.add_child(cn_row)
	var cn_lbl := Label.new(); cn_lbl.text = "Pose lock:"; cn_lbl.custom_minimum_size = Vector2(80, 0)
	cn_row.add_child(cn_lbl)
	_controlnet_check = CheckBox.new()
	_controlnet_check.text = "Use ControlNet OpenPose (animation presets)"
	_controlnet_check.button_pressed = bool(_load_setting(_SETTINGS_USE_CONTROLNET, true))
	_controlnet_check.tooltip_text = "When ON, animation presets send a per-frame stick-figure pose to ControlNet OpenPose so the character keeps consistent body posture across frames. Requires the Local SD (A1111) backend with the sd-webui-controlnet extension installed."
	_controlnet_check.toggled.connect(func(p): _save_setting(_SETTINGS_USE_CONTROLNET, p))
	cn_row.add_child(_controlnet_check)

	# Remove background — runs the result through rembg before pixelify so
	# the final 32×32 has clean alpha instead of speckled "background" noise.
	# Default ON for new users; cheap CPU pass that runs server-side.
	var rb_row := HBoxContainer.new()
	controls.add_child(rb_row)
	var rb_lbl := Label.new(); rb_lbl.text = "Cleanup:"; rb_lbl.custom_minimum_size = Vector2(80, 0)
	rb_row.add_child(rb_lbl)
	_remove_bg_check = CheckBox.new()
	_remove_bg_check.text = "Remove background (recommended for sprites)"
	_remove_bg_check.button_pressed = bool(_load_setting(_SETTINGS_REMOVE_BG, true))
	_remove_bg_check.tooltip_text = "When ON, the generated image is run through rembg (U²-Net) to cut out the subject. Eliminates the colorful checkerboard 'noise floor' artifacts you get when SD fills the background. Requires the Local SD (A1111) backend with sd-webui-rembg installed."
	_remove_bg_check.toggled.connect(func(p): _save_setting(_SETTINGS_REMOVE_BG, p))
	rb_row.add_child(_remove_bg_check)

	controls.add_child(HSeparator.new())

	# Buttons
	var btn_row := HBoxContainer.new()
	controls.add_child(btn_row)
	_generate_btn = Button.new()
	_generate_btn.text = "Generate"
	_generate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_generate_btn.pressed.connect(_on_generate_pressed)
	btn_row.add_child(_generate_btn)
	_save_btn = Button.new()
	_save_btn.text = "Save to Project…"
	_save_btn.disabled = true
	_save_btn.pressed.connect(_on_save_pressed)
	btn_row.add_child(_save_btn)

	# Status
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label.modulate = Color(0.7, 0.7, 0.7)
	controls.add_child(_status_label)

	# spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)

	# ── Right: preview ───────────────────────────────────────────
	var preview_box := VBoxContainer.new()
	preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(preview_box)

	var pv_title := Label.new()
	pv_title.text = "Preview"
	preview_box.add_child(pv_title)

	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Match the dark editor theme: pull base/dark color from editor so the
	# preview panel doesn't render as bright white in dark themes.
	var _ed_base := EditorInterface.get_base_control()
	var _bg_col := Color(0.12, 0.12, 0.14)
	var _border_col := Color(0.25, 0.25, 0.30)
	if _ed_base != null:
		if _ed_base.has_theme_color("dark_color_2", "Editor"):
			_bg_col = _ed_base.get_theme_color("dark_color_2", "Editor")
		elif _ed_base.has_theme_color("base_color", "Editor"):
			_bg_col = _ed_base.get_theme_color("base_color", "Editor")
		if _ed_base.has_theme_color("contrast_color_1", "Editor"):
			_border_col = _ed_base.get_theme_color("contrast_color_1", "Editor")
	var _preview_sb := StyleBoxFlat.new()
	_preview_sb.bg_color = _bg_col
	_preview_sb.border_color = _border_col
	_preview_sb.set_border_width_all(1)
	_preview_sb.set_corner_radius_all(3)
	_preview_sb.set_content_margin_all(6)
	preview_panel.add_theme_stylebox_override("panel", _preview_sb)
	preview_box.add_child(preview_panel)

	_preview_rect = TextureRect.new()
	_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(_preview_rect)

	# Themed busy view: spinner + status, plus a rotating reassurance tip
	# below. Hidden when not generating.
	_busy_box = VBoxContainer.new()
	_busy_box.visible = false
	_busy_box.add_theme_constant_override("separation", 2)
	preview_box.add_child(_busy_box)

	var _accent_col := Color(0.40, 0.70, 1.00)
	var _font_col := Color(0.85, 0.85, 0.85)
	var _dim_col := Color(0.60, 0.60, 0.65)
	if _ed_base != null:
		if _ed_base.has_theme_color("accent_color", "Editor"):
			_accent_col = _ed_base.get_theme_color("accent_color", "Editor")
		if _ed_base.has_theme_color("font_color", "Label"):
			_font_col = _ed_base.get_theme_color("font_color", "Label")
		_dim_col = Color(_font_col.r, _font_col.g, _font_col.b, 0.6)

	_busy_status = Label.new()
	_busy_status.text = ""
	_busy_status.add_theme_color_override("font_color", _accent_col)
	_busy_box.add_child(_busy_status)

	_busy_tip = Label.new()
	_busy_tip.text = ""
	_busy_tip.add_theme_color_override("font_color", _dim_col)
	_busy_tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	_busy_box.add_child(_busy_tip)

	# Legacy alias — some other code paths still reference _busy_indicator.
	_busy_indicator = _busy_status

	_busy_anim_timer = Timer.new()
	_busy_anim_timer.wait_time = 0.12
	_busy_anim_timer.one_shot = false
	_busy_anim_timer.autostart = false
	_busy_anim_timer.timeout.connect(_on_busy_tick)
	_view.add_child(_busy_anim_timer)

	# Animation playback row (only meaningful for multi-frame sheets).
	var play_row := HBoxContainer.new()
	preview_box.add_child(play_row)
	_play_btn = Button.new()
	_play_btn.text = "▶ Play"
	_play_btn.disabled = true
	_play_btn.tooltip_text = "Play the generated frames as an animation."
	_play_btn.pressed.connect(_on_play_toggled)
	play_row.add_child(_play_btn)
	var fps_lbl := Label.new(); fps_lbl.text = "FPS:"
	play_row.add_child(fps_lbl)
	_fps_spin = SpinBox.new()
	_fps_spin.min_value = 1
	_fps_spin.max_value = 30
	_fps_spin.value = 8
	_fps_spin.tooltip_text = "Playback speed."
	_fps_spin.value_changed.connect(_on_fps_changed)
	play_row.add_child(_fps_spin)

	_anim_timer = Timer.new()
	_anim_timer.one_shot = false
	_anim_timer.wait_time = 1.0 / 8.0
	_anim_timer.timeout.connect(_on_anim_tick)
	preview_box.add_child(_anim_timer)

	# Restore selections
	var saved_backend := _load_setting(_SETTINGS_BACKEND, "pollinations")
	for i in _backends.size():
		if _backends[i].get_id() == saved_backend:
			_backend_dd.select(i)
			break
	_on_backend_changed(_backend_dd.selected)

	# Make OptionButton dropdowns readable. Editor themes paint these popups
	# nearly invisibly; we apply the proven recipe from vg_ai_help.gd.
	_style_dropdown_popup(_backend_dd)
	_style_dropdown_popup(_preset_dd)
	_style_dropdown_popup(_layout_dd)

	# Force readable font colors on every Label / TextEdit / LineEdit /
	# Button / SpinBox in the main panel. The editor theme paints them
	# dark-on-dark by default. We do this *last* so it overrides anything
	# the controls' own constructors may have set.
	_force_panel_colors(_view)


# Walk the tree and apply per-control color overrides so the panel reads
# correctly regardless of the host editor theme. Doesn't touch Window-
# derived nodes (PopupMenu, AcceptDialog) — those have their own helpers.
#
# `light_bg=true` flips the palette: dark text + light input boxes, suitable
# for AcceptDialog content (the dialog's own panel paints a light/cream bg
# we can't easily restyle, and a Button/OptionButton in there showed up
# light-on-light with the dark palette).
func _force_panel_colors(node: Node, light_bg: bool = false) -> void:
	var FG := Color(0.92, 0.92, 0.94) if not light_bg else Color(0.05, 0.05, 0.08)
	var FG_DIM := Color(0.65, 0.65, 0.70) if not light_bg else Color(0.40, 0.40, 0.45)
	var FG_PLACEHOLDER := Color(0.55, 0.55, 0.60) if not light_bg else Color(0.45, 0.45, 0.50)
	var FG_HIGHLIGHT := Color(1, 1, 1) if not light_bg else Color(0, 0, 0)
	var BG_INPUT := Color(0.20, 0.20, 0.24) if not light_bg else Color(0.97, 0.97, 0.99)
	var BORDER := Color(0.35, 0.35, 0.40) if not light_bg else Color(0.55, 0.55, 0.60)
	var SEL := Color(0.30, 0.50, 0.85, 0.55)

	if node is Label:
		# Don't stomp labels that were intentionally dimmed via modulate
		# (e.g. the "Free hosted backend…" hint). modulate stacks on top
		# of font_color, so setting font_color is still safe.
		(node as Label).add_theme_color_override("font_color", FG)
	elif node is TextEdit:
		var te: TextEdit = node
		te.add_theme_color_override("font_color", FG)
		te.add_theme_color_override("font_placeholder_color", FG_PLACEHOLDER)
		te.add_theme_color_override("font_selected_color", FG_HIGHLIGHT)
		te.add_theme_color_override("caret_color", FG)
		te.add_theme_color_override("selection_color", SEL)
		var box := StyleBoxFlat.new()
		box.bg_color = BG_INPUT
		box.set_border_width_all(1)
		box.border_color = BORDER
		box.set_corner_radius_all(3)
		box.set_content_margin_all(4)
		te.add_theme_stylebox_override("normal", box)
		te.add_theme_stylebox_override("focus", box)
		te.add_theme_stylebox_override("read_only", box)
	elif node is LineEdit:
		var le: LineEdit = node
		le.add_theme_color_override("font_color", FG)
		le.add_theme_color_override("font_placeholder_color", FG_PLACEHOLDER)
		le.add_theme_color_override("font_selected_color", FG_HIGHLIGHT)
		le.add_theme_color_override("caret_color", FG)
		le.add_theme_color_override("selection_color", SEL)
		var box := StyleBoxFlat.new()
		box.bg_color = BG_INPUT
		box.set_border_width_all(1)
		box.border_color = BORDER
		box.set_corner_radius_all(3)
		box.set_content_margin_all(4)
		le.add_theme_stylebox_override("normal", box)
		le.add_theme_stylebox_override("focus", box)
		le.add_theme_stylebox_override("read_only", box)
	elif node is Button or node is OptionButton:
		# Buttons including OptionButton (which extends Button).
		node.add_theme_color_override("font_color", FG)
		node.add_theme_color_override("font_hover_color", FG_HIGHLIGHT)
		node.add_theme_color_override("font_pressed_color", FG_HIGHLIGHT)
		node.add_theme_color_override("font_focus_color", FG_HIGHLIGHT)
		node.add_theme_color_override("font_disabled_color", FG_DIM)
		# The host editor theme sometimes paints OptionButton with a
		# near-white stylebox, so our 0.92 font_color renders invisibly.
		# Force a stylebox that contrasts with the chosen text color.
		var nbox := StyleBoxFlat.new()
		nbox.bg_color = BG_INPUT
		nbox.set_border_width_all(1)
		nbox.border_color = BORDER
		nbox.set_corner_radius_all(3)
		nbox.set_content_margin_all(4)
		var hbox := nbox.duplicate() as StyleBoxFlat
		hbox.bg_color = Color(0.26, 0.26, 0.30) if not light_bg else Color(0.88, 0.90, 0.96)
		var pbox := nbox.duplicate() as StyleBoxFlat
		pbox.bg_color = Color(0.16, 0.16, 0.20) if not light_bg else Color(0.78, 0.82, 0.92)
		for s in ["normal", "focus", "disabled"]:
			node.add_theme_stylebox_override(s, nbox)
		node.add_theme_stylebox_override("hover", hbox)
		node.add_theme_stylebox_override("pressed", pbox)
	elif node is SpinBox:
		(node as SpinBox).add_theme_color_override("font_color", FG)
	elif node is CheckBox or node is CheckButton:
		node.add_theme_color_override("font_color", FG)

	for child in node.get_children():
		_force_panel_colors(child, light_bg)


# ─── Popup styling ────────────────────────────────────────────────
#
# Recipe straight from /memories/repo/gdscript_landmines.md ("OptionButton
# dropdown — dark-on-dark unreadable popup"). The Godot editor theme
# leaks into PopupMenu and paints `font_color` (and friends) with alpha=0,
# so unhovered rows render invisible. NEVER set popup.modulate /
# self_modulate — PopupMenu extends Window, not Control, and assigning
# either property raises a runtime error that aborts the rest of this
# function silently.

func _style_dropdown_popup(option_btn: OptionButton) -> void:
	if not is_instance_valid(option_btn):
		return
	var popup := option_btn.get_popup()
	if popup == null:
		return
	_apply_light_popup_styling(popup)
	# Re-apply right before each show — the editor theme stomps font_color
	# between our setup and the popup's first paint.
	if not popup.about_to_popup.is_connected(_on_dropdown_popup_about_to_show):
		popup.about_to_popup.connect(_on_dropdown_popup_about_to_show.bind(popup))


func _on_dropdown_popup_about_to_show(popup: PopupMenu) -> void:
	if is_instance_valid(popup):
		_apply_light_popup_styling(popup)


func _apply_light_popup_styling(popup: PopupMenu) -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.94, 0.94, 0.96)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.55, 0.55, 0.62)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(4)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.30, 0.50, 0.85)
	hover_style.set_corner_radius_all(3)

	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.70, 0.70, 0.75)
	sep_style.set_content_margin_all(0)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1

	var t := Theme.new()
	t.set_stylebox("panel", "PopupMenu", panel_style)
	t.set_stylebox("hover", "PopupMenu", hover_style)
	t.set_stylebox("separator", "PopupMenu", sep_style)
	t.set_stylebox("labeled_separator_left", "PopupMenu", sep_style)
	t.set_stylebox("labeled_separator_right", "PopupMenu", sep_style)
	t.set_color("font_color", "PopupMenu", Color.BLACK)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", Color(0.55, 0.55, 0.55))
	t.set_color("font_separator_color", "PopupMenu", Color(0.4, 0.4, 0.4))
	t.set_color("font_accelerator_color", "PopupMenu", Color(0.25, 0.35, 0.6))
	t.set_stylebox("panel", "PopupPanel", panel_style)
	popup.theme = t

	popup.add_theme_stylebox_override("panel", panel_style)
	popup.add_theme_stylebox_override("hover", hover_style)
	popup.add_theme_stylebox_override("separator", sep_style)
	popup.add_theme_stylebox_override("labeled_separator_left", sep_style)
	popup.add_theme_stylebox_override("labeled_separator_right", sep_style)
	popup.add_theme_color_override("font_color", Color.BLACK)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	popup.add_theme_color_override("font_separator_color", Color(0.4, 0.4, 0.4))
	popup.add_theme_color_override("font_accelerator_color", Color(0.25, 0.35, 0.6))
	# Kill any text outline that the editor theme may have applied — a
	# transparent outline with non-zero size silently eats glyph alpha.
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	popup.add_theme_constant_override("outline_size", 0)

	# Force a known-good font onto the popup. The editor theme can hand
	# OptionButton popups a font whose ASCII glyphs render with broken
	# alpha while the system color-emoji fallback renders fine — symptom
	# is "icons/emoji visible, text invisible".
	var good_font: Font = null
	var owner_btn := popup.get_parent() as OptionButton
	if owner_btn != null:
		good_font = owner_btn.get_theme_font("font")
	if good_font == null and Engine.is_editor_hint():
		var base := EditorInterface.get_base_control()
		if base != null:
			good_font = base.get_theme_font("font")
	if good_font != null:
		popup.add_theme_font_override("font", good_font)
		var fs := 0
		if owner_btn != null:
			fs = owner_btn.get_theme_font_size("font_size")
		if fs > 0:
			popup.add_theme_font_size_override("font_size", fs)

	popup.transparent = false
	popup.notification(Window.NOTIFICATION_THEME_CHANGED)

	# Defensive: explicitly clear focus/pressed/selected color slots so no
	# editor-theme leftover repaints the selected item with alpha=0.
	for color_name in ["font_focus_color", "font_pressed_color", "font_selected_color"]:
		popup.add_theme_color_override(color_name, Color.BLACK)

# ─── Backend handling ────────────────────────────────────────────

func _on_preset_changed(idx: int) -> void:
	if idx < 0 or idx >= _preset_dd.item_count:
		return
	var name: String = _preset_dd.get_item_text(idx)
	if not _PRESETS.has(name):
		return
	var preset: Dictionary = _PRESETS[name]
	# Animation presets specify a frame count — auto-fill the spin and
	# force a row layout (sprite sheets for AnimatedSprite2D expect a strip).
	if preset.has("frames"):
		_frames_spin.value = int(preset.get("frames", 1))
		_layout_dd.select(0)  # Row
	# Auto-fill negative if user hasn't typed one yet.
	if _negative_edit.text.strip_edges().is_empty():
		_negative_edit.placeholder_text = _get_preset_negative(name, preset)


func _on_backend_changed(idx: int) -> void:
	if idx < 0 or idx >= _backends.size():
		return
	_current_backend = _backends[idx]
	_save_setting(_SETTINGS_BACKEND, _current_backend.get_id())
	# Apply persisted token to HF backend.
	if _current_backend.get_id() == "huggingface":
		_current_backend.token = _load_setting(_SETTINGS_HF_TOKEN, "")
		_current_backend.default_model = _load_setting(_SETTINGS_HF_MODEL, _current_backend.default_model)
	elif _current_backend.get_id() == "local_a1111":
		var server := _resolve_a1111_active()
		_current_backend.base_url = String(server.get("url", _A1111_LOCAL_URL))
		_current_backend.auth_user = String(server.get("user", ""))
		_current_backend.auth_pass = String(server.get("pass", ""))
		# Kick a non-blocking reachability check so the status label updates.
		_refresh_a1111_status()
	_update_status()


func _refresh_a1111_status() -> void:
	if _current_backend == null or _current_backend.get_id() != "local_a1111":
		return
	_status_label.modulate = Color(0.7, 0.7, 0.7)
	_status_label.text = "Pinging %s…" % _current_backend.base_url
	await _current_backend.refresh_reachable(_view)
	_update_status()


func _update_status() -> void:
	if _current_backend == null:
		_status_label.text = ""
		return
	if not _current_backend.is_configured():
		_status_label.modulate = Color(0.95, 0.7, 0.4)
		_status_label.text = "⚠ " + _current_backend.get_setup_hint()
		_generate_btn.disabled = true
	else:
		_status_label.modulate = Color(0.6, 0.85, 0.6)
		_status_label.text = "Ready (%s)." % _current_backend.get_display_name()
		_generate_btn.disabled = false


# ─── Generate ────────────────────────────────────────────────────

func _on_generate_pressed() -> void:
	if _current_backend == null:
		return
	var preset_name: String = _preset_dd.get_item_text(_preset_dd.selected)
	var preset: Dictionary = _PRESETS[preset_name]
	_last_preset_name = preset_name

	var user_prompt: String = _prompt_edit.text.strip_edges()
	if user_prompt.is_empty():
		_status_label.modulate = Color(0.9, 0.5, 0.5)
		_status_label.text = "Enter a prompt first."
		return
	_save_setting(_SETTINGS_LAST_PROMPT, user_prompt)

	var full_prompt := user_prompt + _get_preset_suffix(preset_name, preset)
	var negative := _negative_edit.text.strip_edges()
	if negative.is_empty():
		negative = _get_preset_negative(preset_name, preset)

	var base_seed: int = int(_seed_spin.value)
	if base_seed < 0:
		base_seed = randi() & 0x7fffffff

	# Tile-sheet setup
	_frames_total = max(1, int(_frames_spin.value))
	_frames_done = 0
	_frames_collected.clear()
	_frame_seed_base = base_seed
	_frame_preset = preset
	_frame_layout = "grid" if _layout_dd.selected == 1 else "row"
	_frame_params_tmpl = {
		"prompt": full_prompt,
		"negative": negative,
		"width": int(preset.get("gen_w", 512)),
		"height": int(preset.get("gen_h", 512)),
	}

	_save_btn.disabled = true
	_stop_animation()
	_play_btn.disabled = true
	_request_next_frame()


func _request_next_frame() -> void:
	var i := _frames_done
	var params := _frame_params_tmpl.duplicate()

	# Animation: one shared seed so frames stay visually consistent.
	# Sheet variant: seed+i so each tile is a fresh sample.
	var lock_seed: bool = bool(_frame_preset.get("lock_seed", false))
	params["seed"] = _frame_seed_base if lock_seed else (_frame_seed_base + i)

	# Per-frame prompt variation for animation presets.
	var fp: Array = _frame_preset.get("frame_prompts", [])
	if fp.size() > 0:
		var variant: String = String(fp[i % fp.size()])
		params["prompt"] = String(_frame_params_tmpl["prompt"]) + variant

	# ControlNet OpenPose: render a per-frame stick figure and pass via
	# the alwayson_scripts API. Only applies to the A1111 backend (which
	# is the only one that consumes `controlnet_pose_b64`); other backends
	# silently ignore the param.
	var pose_frames: Array = _frame_preset.get("pose_frames", [])
	var use_cn := _controlnet_check != null and _controlnet_check.button_pressed
	if use_cn and pose_frames.size() > 0 \
			and _current_backend != null and _current_backend.get_id() == "local_a1111":
		var keypoints: Array = pose_frames[i % pose_frames.size()]
		var pose_w: int = int(_frame_params_tmpl.get("width", 512))
		var pose_h: int = int(_frame_params_tmpl.get("height", 512))
		params["controlnet_pose_b64"] = _PoseRenderer.render_b64(keypoints, pose_w, pose_h, 8, 6)
		params["controlnet_weight"] = 1.0

	if _frames_total > 1:
		_set_busy(true, "Generating frame %d / %d…" % [i + 1, _frames_total])
	else:
		_set_busy(true, "Generating… (this may take 10–40 s)")

	_disconnect_frame_callbacks()
	_frame_ok_cb = func(img: Image): _on_frame_ok(img)
	_frame_err_cb = func(err: String): _on_generate_failed(err)
	_current_backend.image_ready.connect(_frame_ok_cb, CONNECT_ONE_SHOT)
	_current_backend.failed.connect(_frame_err_cb, CONNECT_ONE_SHOT)
	_current_backend.generate(_view, params)


func _disconnect_frame_callbacks() -> void:
	if _current_backend == null:
		return
	if _frame_ok_cb.is_valid() and _current_backend.image_ready.is_connected(_frame_ok_cb):
		_current_backend.image_ready.disconnect(_frame_ok_cb)
	if _frame_err_cb.is_valid() and _current_backend.failed.is_connected(_frame_err_cb):
		_current_backend.failed.disconnect(_frame_err_cb)


func _on_frame_ok(img: Image) -> void:
	if img == null or img.is_empty():
		_on_generate_failed("Got an empty image back on frame %d." % (_frames_done + 1))
		return

	# Optional pre-pixelify cleanup: rembg cuts out the subject so the
	# subsequent downscale doesn't smear background noise into the sprite.
	# Only meaningful for the local A1111 backend; other backends skip it.
	var cleaned: Image = img
	var want_rembg: bool = _remove_bg_check != null and _remove_bg_check.button_pressed
	if want_rembg and _current_backend != null and _current_backend.get_id() == "local_a1111":
		_set_busy(true, "Removing background…")
		cleaned = await _current_backend.remove_background_async(_view, img)
		if cleaned == null:
			cleaned = img

	# Strip mode: one returned image contains N side-by-side frames.
	# Slice horizontally, pixelify each slice, then jump straight to the
	# sheet-compose stage. This is how the "Walk Strip 4f (Pollinations)"
	# preset works — single API call, no ControlNet needed.
	var strip_count: int = int(_frame_preset.get("strip_count", 0))
	if strip_count > 1:
		var slice_w: int = cleaned.get_width() / strip_count
		var slice_h: int = cleaned.get_height()
		var out_w_s: int = int(_frame_preset.get("out_w", 0))
		var out_h_s: int = int(_frame_preset.get("out_h", 0))
		var alpha_key_s: Color = _frame_preset.get("alpha_key", Color(0,0,0,0))
		var alpha_tol_s: float = float(_frame_preset.get("alpha_key_tolerance", 0.0))
		if want_rembg:
			alpha_key_s = Color(0, 0, 0, 0)
			alpha_tol_s = 0.0
		for s in strip_count:
			var slice := Image.create(slice_w, slice_h, false, cleaned.get_format())
			slice.blit_rect(cleaned, Rect2i(s * slice_w, 0, slice_w, slice_h), Vector2i(0, 0))
			var slice_done: Image = slice
			if out_w_s > 0 and out_h_s > 0:
				slice_done = _Pixelify.pixelify(
					slice, out_w_s, out_h_s,
					int(_frame_preset.get("palette_steps", 0)),
					alpha_key_s,
					alpha_tol_s
				)
			_frames_collected.append(slice_done)
		_frames_done = _frames_total  # short-circuit the per-frame loop
		_disconnect_frame_callbacks()
		_finalize_sheet()
		return

	# Apply per-frame post-pass so individual frames are pixelified before compose.
	var out_w: int = int(_frame_preset.get("out_w", 0))
	var out_h: int = int(_frame_preset.get("out_h", 0))
	var processed: Image = cleaned
	if out_w > 0 and out_h > 0:
		# When rembg already produced clean alpha, skip the alpha key step
		# entirely (passing alpha 0 disables it).
		var alpha_key: Color = _frame_preset.get("alpha_key", Color(0,0,0,0))
		var alpha_tol: float = float(_frame_preset.get("alpha_key_tolerance", 0.0))
		if want_rembg:
			alpha_key = Color(0, 0, 0, 0)
			alpha_tol = 0.0
		processed = _Pixelify.pixelify(
			cleaned, out_w, out_h,
			int(_frame_preset.get("palette_steps", 0)),
			alpha_key,
			alpha_tol
		)

	_frames_collected.append(processed)
	_frames_done += 1

	if _frames_done < _frames_total:
		_disconnect_frame_callbacks()
		_request_next_frame()
		return

	_finalize_sheet()


## Compose `_frames_collected` into the final sheet, push it to the
## preview, and update the status label. Shared by the per-frame loop
## and by single-call strip presets.
func _finalize_sheet() -> void:
	# All frames collected — compose sheet (or pass through single image).
	_set_busy(false, "")
	var sheet: Image
	if _frames_collected.size() == 1:
		sheet = _frames_collected[0]
		_last_frame_count = 1
		_last_frame_w = sheet.get_width()
		_last_frame_h = sheet.get_height()
	else:
		sheet = _compose_sheet(_frames_collected, _frame_layout)

	_last_image = sheet
	_preview_rect.texture = ImageTexture.create_from_image(sheet)
	_anim_full_tex = _preview_rect.texture
	_save_btn.disabled = false
	# Enable playback only for multi-frame row layouts (grid sheets are
	# meant for variants, not animation).
	var anim_ok := (_last_frame_count > 1) and (_frame_layout == "row")
	_play_btn.disabled = not anim_ok
	if not anim_ok:
		_stop_animation()
	_status_label.modulate = Color(0.6, 0.85, 0.6)
	if _last_frame_count > 1:
		_status_label.text = "Done. Sheet %dx%d (%d frames @ %dx%d) ready to save." % [
			sheet.get_width(), sheet.get_height(),
			_last_frame_count, _last_frame_w, _last_frame_h
		]
	else:
		_status_label.text = "Done. %dx%d ready to save." % [sheet.get_width(), sheet.get_height()]


func _compose_sheet(frames: Array, layout: String) -> Image:
	var n := frames.size()
	var fw: int = (frames[0] as Image).get_width()
	var fh: int = (frames[0] as Image).get_height()
	var cols := n
	var rows := 1
	if layout == "grid":
		cols = int(ceil(sqrt(float(n))))
		rows = int(ceil(float(n) / float(cols)))
	var sheet := Image.create(fw * cols, fh * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for i in n:
		var f: Image = frames[i]
		# Defensive: enforce uniform frame size by resizing odd ones.
		if f.get_width() != fw or f.get_height() != fh:
			f = f.duplicate()
			f.resize(fw, fh, Image.INTERPOLATE_NEAREST)
		if f.get_format() != Image.FORMAT_RGBA8:
			f = f.duplicate()
			f.convert(Image.FORMAT_RGBA8)
		var col := i % cols
		var row := i / cols
		sheet.blit_rect(f, Rect2i(0, 0, fw, fh), Vector2i(col * fw, row * fh))
	_last_frame_count = n
	_last_frame_w = fw
	_last_frame_h = fh
	return sheet


# ─── Animation preview ───────────────────────────────────────────

func _on_play_toggled() -> void:
	if _anim_timer == null:
		return
	if _anim_timer.is_stopped():
		_start_animation()
	else:
		_stop_animation()


func _start_animation() -> void:
	if _last_image == null or _last_frame_count <= 1 or _last_frame_w <= 0:
		return
	_anim_frame_idx = 0
	_anim_timer.wait_time = 1.0 / max(1.0, float(_fps_spin.value))
	_anim_timer.start()
	_play_btn.text = "⏸ Pause"
	# Render frame 0 immediately so motion starts on click.
	_on_anim_tick()


func _stop_animation() -> void:
	if _anim_timer != null and not _anim_timer.is_stopped():
		_anim_timer.stop()
	if _play_btn != null:
		_play_btn.text = "▶ Play"
	# Restore the full-sheet view.
	if _anim_full_tex != null and _preview_rect != null:
		_preview_rect.texture = _anim_full_tex


func _on_anim_tick() -> void:
	if _last_image == null or _last_frame_count <= 1 or _anim_full_tex == null:
		return
	# Crop one frame out of the sheet via AtlasTexture (no per-frame copy).
	var atlas := AtlasTexture.new()
	atlas.atlas = _anim_full_tex
	atlas.region = Rect2(_anim_frame_idx * _last_frame_w, 0, _last_frame_w, _last_frame_h)
	_preview_rect.texture = atlas
	_anim_frame_idx = (_anim_frame_idx + 1) % _last_frame_count


func _on_fps_changed(_v: float) -> void:
	if _anim_timer != null and not _anim_timer.is_stopped():
		_anim_timer.wait_time = 1.0 / max(1.0, float(_fps_spin.value))


func _on_generate_failed(err: String) -> void:
	_set_busy(false, "")
	_status_label.modulate = Color(0.9, 0.5, 0.5)
	_status_label.text = "Failed: " + err
	push_warning("[VG AI Art] " + err)
	_disconnect_frame_callbacks()
	# Reset multi-frame state so a retry starts clean.
	_frames_done = 0
	_frames_collected.clear()


func _set_busy(busy: bool, msg: String) -> void:
	_generate_btn.disabled = busy or (_current_backend == null) or (not _current_backend.is_configured())
	_busy_status_text = msg
	if _busy_box == null:
		# Pre-init fallback (shouldn't happen in practice).
		if _busy_indicator != null:
			_busy_indicator.text = msg
		return
	if busy:
		_busy_box.visible = true
		_busy_started_us = Time.get_ticks_msec()
		_busy_spin_idx = 0
		_busy_tip_idx = randi() % _BUSY_TIPS.size()
		_busy_tip_next_change_s = 5.0
		_busy_tip.text = _BUSY_TIPS[_busy_tip_idx]
		_redraw_busy_status()
		if _busy_anim_timer != null and _busy_anim_timer.is_stopped():
			_busy_anim_timer.start()
	else:
		_busy_box.visible = false
		_busy_status.text = ""
		_busy_tip.text = ""
		if _busy_anim_timer != null and not _busy_anim_timer.is_stopped():
			_busy_anim_timer.stop()


func _redraw_busy_status() -> void:
	if _busy_status == null:
		return
	var elapsed_s: float = float(Time.get_ticks_msec() - _busy_started_us) / 1000.0
	var mins: int = int(elapsed_s) / 60
	var secs: int = int(elapsed_s) % 60
	var spin: String = _BUSY_SPIN_FRAMES[_busy_spin_idx % _BUSY_SPIN_FRAMES.size()]
	_busy_status.text = "%s  %s   (elapsed %d:%02d)" % [spin, _busy_status_text, mins, secs]


func _on_busy_tick() -> void:
	_busy_spin_idx += 1
	# Rotate tip every ~5 seconds — keeps the UI feeling alive without
	# spamming. Tick fires every 0.12s, so 5s ≈ 42 ticks.
	var elapsed_s: float = float(Time.get_ticks_msec() - _busy_started_us) / 1000.0
	if elapsed_s >= _busy_tip_next_change_s and _busy_tip != null:
		_busy_tip_idx = (_busy_tip_idx + 1) % _BUSY_TIPS.size()
		_busy_tip.text = _BUSY_TIPS[_busy_tip_idx]
		_busy_tip_next_change_s = elapsed_s + 5.0
	_redraw_busy_status()


# ─── Save ────────────────────────────────────────────────────────

func _on_save_pressed() -> void:
	if _last_image == null:
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.png ; PNG image"])
	dialog.current_path = "res://assets/ai_art/"
	var suggested := _suggest_filename()
	dialog.current_file = suggested
	dialog.title = "Save AI Art"
	_view.add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		_save_image_to(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered_ratio(0.7)


func _save_image_to(path: String) -> void:
	if not path.to_lower().ends_with(".png"):
		path += ".png"
	var dir := path.get_base_dir()
	if dir.begins_with("res://"):
		var d := DirAccess.open("res://")
		if d:
			d.make_dir_recursive(dir.trim_prefix("res://"))
	var err := _last_image.save_png(path)
	if err != OK:
		_status_label.modulate = Color(0.9, 0.5, 0.5)
		_status_label.text = "Could not save to %s (err %d)" % [path, err]
		return
	_status_label.modulate = Color(0.6, 0.85, 0.6)
	_status_label.text = "Saved → " + path

	# Tell the rest of the IDE so file browsers refresh.
	var bus = _AssetBus.get_instance()
	if bus and bus.has_method("emit_saved"):
		bus.emit_saved(path, "vg_ai_art")

	# For tile sheets, also write a tiny .json sidecar with frame info so
	# the user can wire up SpriteFrames/AtlasTexture without guessing.
	if _last_frame_count > 1:
		var meta := {
			"frame_count": _last_frame_count,
			"frame_width": _last_frame_w,
			"frame_height": _last_frame_h,
			"sheet_width": _last_image.get_width(),
			"sheet_height": _last_image.get_height(),
			"layout": _frame_layout,
			"columns": _last_image.get_width() / max(1, _last_frame_w),
			"rows": _last_image.get_height() / max(1, _last_frame_h),
			"prompt": _prompt_edit.text.strip_edges(),
			"preset": _last_preset_name,
		}
		var json_path := path.get_basename() + ".json"
		var jf := FileAccess.open(json_path, FileAccess.WRITE)
		if jf:
			jf.store_string(JSON.stringify(meta, "  "))
			jf.close()

	# Re-import so the file appears in the Godot editor.
	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		if fs:
			fs.scan()


func _suggest_filename() -> String:
	var slug := _prompt_edit.text.strip_edges().to_lower()
	var clean := ""
	for ch in slug:
		var c: String = ch
		var ok := (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == " " or c == "-" or c == "_"
		if ok:
			clean += c
	clean = clean.strip_edges().replace("  ", " ").replace(" ", "_")
	if clean.length() > 32:
		clean = clean.substr(0, 32)
	if clean.is_empty():
		clean = "ai_art"
	return "%s_%d.png" % [clean, Time.get_unix_time_from_system()]


# ─── Settings popup ──────────────────────────────────────────────


## ─── Saved A1111 servers ─────────────────────────────────────────
##
## The plugin keeps a built-in "Local — this computer" entry plus a
## list of named user-added servers (RunPod, ngrok, LAN box, etc.).
## Stored as a JSON string so it round-trips through ProjectSettings.
func _get_a1111_servers() -> Array:
	var raw: String = String(_load_setting(_SETTINGS_A1111_SERVERS, ""))
	if raw.strip_edges().is_empty():
		return []
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_ARRAY:
		return []
	var out: Array = []
	for item in parsed:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var nm := String(item.get("name", "")).strip_edges()
		var ur := String(item.get("url", "")).strip_edges()
		if nm.is_empty() or ur.is_empty():
			continue
		out.append({
			"name": nm,
			"url": ur,
			"user": String(item.get("user", "")),
			"pass": String(item.get("pass", "")),
		})
	return out


func _save_a1111_servers(arr: Array) -> void:
	_save_setting(_SETTINGS_A1111_SERVERS, JSON.stringify(arr))


## Resolve the active A1111 server. Falls back to the legacy
## single-URL setting so older projects upgrade transparently.
func _resolve_a1111_active() -> Dictionary:
	var name: String = String(_load_setting(_SETTINGS_A1111_ACTIVE, _A1111_LOCAL_NAME))
	if name == _A1111_LOCAL_NAME or name.is_empty():
		var legacy_url: String = String(_load_setting(_SETTINGS_A1111_URL, _A1111_LOCAL_URL))
		return {"name": _A1111_LOCAL_NAME, "url": legacy_url, "user": "", "pass": ""}
	for s in _get_a1111_servers():
		if String(s.get("name", "")) == name:
			return s.duplicate()
	return {"name": _A1111_LOCAL_NAME, "url": _A1111_LOCAL_URL, "user": "", "pass": ""}


## Modal editor for one saved server. `existing` is the current values
## (empty dict for "Add new"). Calls `on_saved.call(dict)` on Save.
func _open_a1111_server_editor(existing: Dictionary, on_saved: Callable) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Add server" if existing.is_empty() else "Edit server"
	dlg.min_size = Vector2(520, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	dlg.add_child(v)

	var name_lbl := Label.new()
	name_lbl.text = "Name (anything you like — shown in the dropdown):"
	v.add_child(name_lbl)
	var name_edit := LineEdit.new()
	name_edit.text = String(existing.get("name", ""))
	name_edit.placeholder_text = "e.g. RunPod RTX 4090, Office LAN box, ngrok tunnel…"
	v.add_child(name_edit)

	var url_lbl := Label.new()
	url_lbl.text = "URL:"
	v.add_child(url_lbl)
	var url_edit := LineEdit.new()
	url_edit.text = String(existing.get("url", ""))
	url_edit.placeholder_text = "https://my-pod-xxxx-7860.proxy.runpod.net  or  http://192.168.1.50:7860"
	v.add_child(url_edit)

	# Quick-fill buttons for popular providers — saves novices from a blank field.
	var chip_row := HBoxContainer.new()
	v.add_child(chip_row)
	var chip_lbl := Label.new()
	chip_lbl.text = "Examples:"
	chip_lbl.modulate = Color(0.65, 0.65, 0.7)
	chip_row.add_child(chip_lbl)
	var chips := [
		["RunPod", "https://YOUR-POD-ID-7860.proxy.runpod.net"],
		["Vast.ai", "http://YOUR-VAST-IP:YOUR-PORT"],
		["LAN", "http://192.168.1.50:7860"],
		["ngrok", "https://YOUR-SUBDOMAIN.ngrok-free.app"],
		["Cloudflare", "https://YOUR-TUNNEL.trycloudflare.com"],
	]
	for c in chips:
		var b := Button.new()
		b.text = c[0]
		b.tooltip_text = "Insert template URL — replace the placeholders with your real values."
		var tmpl := String(c[1])
		var label_name := String(c[0])
		b.pressed.connect(func():
			url_edit.text = tmpl
			if name_edit.text.strip_edges().is_empty():
				name_edit.text = label_name
		)
		chip_row.add_child(b)

	v.add_child(HSeparator.new())

	var auth_lbl := Label.new()
	auth_lbl.text = "Optional username / password (HTTP Basic auth — only if your server is protected):"
	auth_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	auth_lbl.modulate = Color(0.7, 0.7, 0.7)
	v.add_child(auth_lbl)
	var auth_row := HBoxContainer.new()
	v.add_child(auth_row)
	var user_edit := LineEdit.new()
	user_edit.placeholder_text = "username (leave blank if none)"
	user_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	user_edit.text = String(existing.get("user", ""))
	auth_row.add_child(user_edit)
	var pass_edit := LineEdit.new()
	pass_edit.secret = true
	pass_edit.placeholder_text = "password"
	pass_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_edit.text = String(existing.get("pass", ""))
	auth_row.add_child(pass_edit)

	# Inline test button so the user can verify before saving.
	var test_row := HBoxContainer.new()
	v.add_child(test_row)
	var test_btn := Button.new()
	test_btn.text = "Test connection"
	test_row.add_child(test_btn)
	var test_status := Label.new()
	test_status.modulate = Color(0.7, 0.7, 0.7)
	test_row.add_child(test_status)
	test_btn.pressed.connect(func():
		var tester = _LocalA1111.new()
		tester.base_url = url_edit.text.strip_edges()
		tester.auth_user = user_edit.text
		tester.auth_pass = pass_edit.text
		test_status.modulate = Color(0.7, 0.7, 0.7)
		test_status.text = "Pinging…"
		await tester.refresh_reachable(_view)
		if tester.is_configured():
			test_status.modulate = Color(0.6, 0.85, 0.6)
			test_status.text = "✓ Reachable"
		else:
			test_status.modulate = Color(0.95, 0.6, 0.4)
			test_status.text = "✗ " + tester._last_check_msg
	)

	dlg.ok_button_text = "Save"
	dlg.confirmed.connect(func():
		var nm := name_edit.text.strip_edges()
		var ur := url_edit.text.strip_edges()
		if nm.is_empty() or ur.is_empty():
			_show_message("A server needs both a name and a URL.")
			return
		if nm == _A1111_LOCAL_NAME:
			_show_message("That name is reserved. Pick a different one.")
			return
		on_saved.call({
			"name": nm,
			"url": ur,
			"user": user_edit.text,
			"pass": pass_edit.text,
		})
	)
	_view.add_child(dlg)
	var sz := Vector2i(560, 360)
	dlg.popup_centered(sz)
	dlg.size = sz
	call_deferred("_force_dialog_size", dlg, sz)
	_force_panel_colors(dlg, true)


func _show_settings_dialog() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "AI Art — Backend Settings"
	dlg.min_size = Vector2(480, 0)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	dlg.add_child(v)

	var hf_lbl := Label.new()
	hf_lbl.text = "Hugging Face access token:"
	v.add_child(hf_lbl)
	var hf_edit := LineEdit.new()
	hf_edit.secret = true
	hf_edit.placeholder_text = "hf_xxx… (free at huggingface.co/settings/tokens)"
	hf_edit.text = _load_setting(_SETTINGS_HF_TOKEN, "")
	v.add_child(hf_edit)

	var hf_model_lbl := Label.new()
	hf_model_lbl.text = "Hugging Face model id:"
	v.add_child(hf_model_lbl)
	var hf_model_edit := LineEdit.new()
	hf_model_edit.text = _load_setting(_SETTINGS_HF_MODEL, "black-forest-labs/FLUX.1-schnell")
	v.add_child(hf_model_edit)

	v.add_child(HSeparator.new())

	# ─── Local / Remote A1111 server picker ───
	# Friendly UX: a "Server" dropdown listing the local default plus any
	# named cloud/LAN servers the user has saved. Advanced section reveals
	# the actual URL + Basic-auth fields and Install/Start buttons. New
	# users can ignore everything here and just click Generate.
	var a1111_lbl := Label.new()
	a1111_lbl.text = "Stable Diffusion server:"
	v.add_child(a1111_lbl)

	var server_row := HBoxContainer.new()
	v.add_child(server_row)
	var server_dd := OptionButton.new()
	server_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_row.add_child(server_dd)
	var add_btn := Button.new()
	add_btn.text = "+ Add…"
	add_btn.tooltip_text = "Add a new cloud or LAN server (RunPod, ngrok, Cloudflare Tunnel, 192.168.x.x, etc.)"
	server_row.add_child(add_btn)
	var edit_btn := Button.new()
	edit_btn.text = "Edit"
	server_row.add_child(edit_btn)
	var del_btn := Button.new()
	del_btn.text = "✕"
	del_btn.tooltip_text = "Remove the selected saved server"
	server_row.add_child(del_btn)

	# Test row (kept for the active server).
	var test_row := HBoxContainer.new()
	v.add_child(test_row)
	var a1111_refresh := Button.new()
	a1111_refresh.text = "Test connection"
	test_row.add_child(a1111_refresh)
	var a1111_status := Label.new()
	a1111_status.text = ""
	a1111_status.modulate = Color(0.7, 0.7, 0.7)
	test_row.add_child(a1111_status)

	# Working state: edits made in the dialog before OK is pressed.
	var pending_active: Array = [_load_setting(_SETTINGS_A1111_ACTIVE, _A1111_LOCAL_NAME)]
	var pending_servers: Array = [_get_a1111_servers().duplicate(true)]

	var refresh_dropdown := func():
		server_dd.clear()
		# Built-in local entry is always index 0.
		server_dd.add_item("%s  (%s)" % [_A1111_LOCAL_NAME, _A1111_LOCAL_URL], 0)
		var sel_idx := 0
		var i := 1
		for s in pending_servers[0]:
			if typeof(s) != TYPE_DICTIONARY:
				continue
			var nm := String(s.get("name", "Unnamed"))
			var url_txt := String(s.get("url", ""))
			var has_auth := not String(s.get("user", "")).is_empty()
			var label := "%s  (%s%s)" % [nm, url_txt, "  🔒" if has_auth else ""]
			server_dd.add_item(label, i)
			if nm == String(pending_active[0]):
				sel_idx = i
			i += 1
		server_dd.select(sel_idx)
		# Local entry isn't editable/removable.
		var on_local: bool = server_dd.selected == 0
		edit_btn.disabled = on_local
		del_btn.disabled = on_local
	refresh_dropdown.call()

	var current_choice := func() -> Dictionary:
		var idx := server_dd.selected
		if idx <= 0:
			return {"name": _A1111_LOCAL_NAME, "url": _A1111_LOCAL_URL, "user": "", "pass": ""}
		var entry: Dictionary = pending_servers[0][idx - 1]
		return {
			"name": String(entry.get("name", "")),
			"url": String(entry.get("url", "")),
			"user": String(entry.get("user", "")),
			"pass": String(entry.get("pass", "")),
		}

	server_dd.item_selected.connect(func(idx: int):
		pending_active[0] = current_choice.call().get("name", _A1111_LOCAL_NAME)
		var on_local: bool = idx == 0
		edit_btn.disabled = on_local
		del_btn.disabled = on_local
		a1111_status.text = ""
	)

	add_btn.pressed.connect(func():
		_open_a1111_server_editor({}, func(saved):
			pending_servers[0].append(saved)
			pending_active[0] = saved.get("name", "")
			refresh_dropdown.call()
		)
	)
	edit_btn.pressed.connect(func():
		var idx := server_dd.selected
		if idx <= 0:
			return
		var existing: Dictionary = pending_servers[0][idx - 1]
		_open_a1111_server_editor(existing, func(saved):
			pending_servers[0][idx - 1] = saved
			pending_active[0] = saved.get("name", "")
			refresh_dropdown.call()
		)
	)
	del_btn.pressed.connect(func():
		var idx := server_dd.selected
		if idx <= 0:
			return
		pending_servers[0].remove_at(idx - 1)
		pending_active[0] = _A1111_LOCAL_NAME
		refresh_dropdown.call()
	)

	a1111_refresh.pressed.connect(func():
		var pick: Dictionary = current_choice.call()
		var tester = _LocalA1111.new()
		tester.base_url = String(pick.get("url", "")).strip_edges()
		tester.auth_user = String(pick.get("user", ""))
		tester.auth_pass = String(pick.get("pass", ""))
		a1111_status.text = "Pinging…"
		a1111_status.modulate = Color(0.7, 0.7, 0.7)
		await tester.refresh_reachable(_view)
		if tester.is_configured():
			a1111_status.modulate = Color(0.6, 0.85, 0.6)
			a1111_status.text = "✓ Reachable"
		else:
			a1111_status.modulate = Color(0.95, 0.6, 0.4)
			a1111_status.text = "✗ " + tester._last_check_msg
	)

	# Install/Start are local-only and risky for novices (10 GB download,
	# CPU-only is slow). Hidden behind an "Advanced" toggle so the dialog
	# stays clean.
	var advanced_check := CheckBox.new()
	advanced_check.text = "Show advanced (install / launch a local SD server on this computer)"
	advanced_check.modulate = Color(0.7, 0.7, 0.7)
	v.add_child(advanced_check)

	var local_tools := HBoxContainer.new()
	local_tools.visible = false
	v.add_child(local_tools)
	var a1111_install_btn := Button.new()
	a1111_install_btn.text = "Install Local SD…"
	a1111_install_btn.tooltip_text = "Download and install AUTOMATIC1111 Stable Diffusion (~10 GB) on this computer. Opens a terminal."
	a1111_install_btn.pressed.connect(_run_a1111_installer)
	local_tools.add_child(a1111_install_btn)
	var a1111_start_btn := Button.new()
	a1111_start_btn.text = "Start Local Server"
	a1111_start_btn.tooltip_text = "Launch ~/stable-diffusion-webui/webui.sh --nowebui --api --port 7860 in a new terminal window."
	a1111_start_btn.pressed.connect(_start_a1111_server)
	local_tools.add_child(a1111_start_btn)
	advanced_check.toggled.connect(func(p: bool): local_tools.visible = p)

	var a1111_hint := Label.new()
	a1111_hint.text = "Most novices should leave this alone and use Pollinations or Hugging Face. Add a cloud GPU server with + Add… (RunPod / ngrok / Cloudflare Tunnel)."
	a1111_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	a1111_hint.modulate = Color(0.65, 0.65, 0.7)
	v.add_child(a1111_hint)

	var note := Label.new()
	note.text = "Pollinations needs no key. Hugging Face is optional but gives better quality and model choice."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.modulate = Color(0.7, 0.7, 0.7)
	v.add_child(note)

	dlg.confirmed.connect(func():
		_save_setting(_SETTINGS_HF_TOKEN, hf_edit.text.strip_edges())
		_save_setting(_SETTINGS_HF_MODEL, hf_model_edit.text.strip_edges())
		# Persist server list + active selection. Keep legacy URL setting
		# in sync so older code paths still see something sensible.
		_save_a1111_servers(pending_servers[0])
		_save_setting(_SETTINGS_A1111_ACTIVE, String(pending_active[0]))
		var resolved := _resolve_a1111_active()
		_save_setting(_SETTINGS_A1111_URL, String(resolved.get("url", _A1111_LOCAL_URL)))
		# Re-apply to current backend.
		_on_backend_changed(_backend_dd.selected)
	)
	_view.add_child(dlg)
	var sz := Vector2i(540, 560)
	dlg.popup_centered(sz)
	dlg.size = sz
	call_deferred("_force_dialog_size", dlg, sz)
	# Force readable colors on the dialog's contents too.
	_force_panel_colors(dlg, true)


## Embedded subwindows (AcceptDialog) ignore both `popup_centered(size)` and
## a one-shot `dlg.size = X` — Godot relayouts on the next frame. Only a
## deferred re-set sticks. See /memories/repo/gdscript_landmines.md §Window
## sizing in embedded subwindow mode.
func _force_dialog_size(dlg: Window, sz: Vector2i) -> void:
	if not is_instance_valid(dlg):
		return
	dlg.size = sz
	var base := EditorInterface.get_base_control()
	var parent_size: Vector2i = Vector2i(base.size) if base != null \
		else Vector2i(_view.get_viewport().get_visible_rect().size)
	dlg.position = (parent_size - sz) / 2
	dlg.position.y = max(0, dlg.position.y)


# ─── Local SD installer ──────────────────────────────────────────

## Run scripts/install_a1111.sh in a new terminal so the user can watch
## the ~10 GB download. Cross-platform best-effort: tries common Linux
## terminals, falls back to macOS Terminal.app, and on Windows runs the
## .ps1 (the script we ship is bash, but Windows users running PowerShell
## will get a friendly message pointing them to WSL or to the URL).
func _run_a1111_installer() -> void:
	# Warn CPU-only users before they kick off the ~10 GB download — they
	# WILL hit minutes-per-frame render times and we want zero surprises.
	if not _has_gpu():
		var warn := ConfirmationDialog.new()
		warn.title = "No GPU detected"
		warn.dialog_text = "Heads up — no compatible GPU was detected on this machine.\n\n"\
			+ "Stable Diffusion will run on CPU. Expect:\n"\
			+ "  • ~5–10 minutes per 512×512 image\n"\
			+ "  • ~30–40 minutes for a 4-frame walk cycle\n"\
			+ "  • ~10 GB of disk for the install\n\n"\
			+ "If you have an NVIDIA GPU but see this message, install the proprietary drivers and try again. "\
			+ "Alternatives:\n"\
			+ "  • Switch the Backend to 'Hugging Face' or 'Pollinations' (free hosted, much faster)\n"\
			+ "  • Point the A1111 URL in Settings at a remote server you control\n\n"\
			+ "Continue with CPU install anyway?"
		warn.ok_button_text = "Install on CPU"
		warn.get_cancel_button().text = "Cancel"
		warn.min_size = Vector2(560, 0)
		_view.add_child(warn)
		warn.popup_centered()
		warn.confirmed.connect(func():
			warn.queue_free()
			_do_run_a1111_installer()
		)
		warn.canceled.connect(func(): warn.queue_free())
		return
	_do_run_a1111_installer()


func _do_run_a1111_installer() -> void:
	var script_path := ProjectSettings.globalize_path(
		"res://addons/visual_gasic/plugins/vgaiart/install_a1111.sh"
	)
	if not FileAccess.file_exists(script_path):
		_show_message("Installer not found at:\n%s" % script_path)
		return

	# Make sure it's executable (FileAccess can't chmod; use OS.execute).
	if OS.get_name() in ["Linux", "macOS", "FreeBSD", "OpenBSD", "NetBSD"]:
		OS.execute("chmod", ["+x", script_path])

	var os_name := OS.get_name()
	var pid := -1
	if os_name == "Linux":
		# Try terminals in order of how commonly they're installed.
		for term in [
			["x-terminal-emulator", ["-e", "bash", script_path]],
			["gnome-terminal", ["--", "bash", script_path]],
			["konsole", ["-e", "bash", script_path]],
			["xfce4-terminal", ["-e", "bash %s" % script_path]],
			["xterm", ["-hold", "-e", "bash", script_path]],
		]:
			pid = OS.create_process(term[0], term[1])
			if pid > 0:
				break
	elif os_name == "macOS":
		# Open Terminal.app with the script as an argument.
		pid = OS.create_process("open", ["-a", "Terminal", script_path])
	elif os_name == "Windows":
		_show_message(
			"Windows users: install AUTOMATIC1111 manually from\n"
			+ "https://github.com/AUTOMATIC1111/stable-diffusion-webui\n\n"
			+ "Then run: webui-user.bat with --api in COMMANDLINE_ARGS."
		)
		return

	if pid <= 0:
		_show_message(
			"Could not open a terminal automatically. Run this in a shell:\n\n"
			+ "  bash %s" % script_path
		)
		return

	_show_post_install_dialog()


func _show_post_install_dialog() -> void:
	var cmd := _a1111_start_command()
	var dlg := AcceptDialog.new()
	dlg.title = "AI Art — Installer launched"
	dlg.min_size = Vector2(520, 0)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	dlg.add_child(v)

	var lbl := Label.new()
	lbl.text = (
		"Installer launched in a new terminal window.\n\n"
		+ "Watch its progress there (~10 GB download, may take 10–30 min).\n\n"
		+ "When it finishes, start the server with the button below, or run"
		+ " this command in a terminal yourself:"
	)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(lbl)

	var cmd_row := HBoxContainer.new()
	v.add_child(cmd_row)
	var cmd_edit := LineEdit.new()
	cmd_edit.text = cmd
	cmd_edit.editable = false
	cmd_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmd_row.add_child(cmd_edit)
	var copy_btn := Button.new()
	copy_btn.text = "Copy"
	copy_btn.pressed.connect(func():
		DisplayServer.clipboard_set(cmd)
		copy_btn.text = "Copied!"
		await _view.get_tree().create_timer(1.5).timeout
		if is_instance_valid(copy_btn):
			copy_btn.text = "Copy"
	)
	cmd_row.add_child(copy_btn)

	var start_btn := Button.new()
	start_btn.text = "Start Server Now"
	start_btn.pressed.connect(func():
		_start_a1111_server()
		dlg.queue_free()
	)
	v.add_child(start_btn)

	var tail := Label.new()
	tail.text = "After the server prints 'Running on http://127.0.0.1:7860', click 'Test connection' in Settings."
	tail.autowrap_mode = TextServer.AUTOWRAP_WORD
	tail.modulate = Color(0.7, 0.7, 0.75)
	v.add_child(tail)

	_view.add_child(dlg)
	dlg.popup_centered()
	_force_panel_colors(dlg, true)
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())


## Build the canonical "start the server" command for the user's platform.
func _a1111_start_command() -> String:
	if OS.get_name() == "Windows":
		return "%USERPROFILE%\\stable-diffusion-webui\\webui-user.bat"
	return "~/stable-diffusion-webui/webui.sh --nowebui --api --port 7860"


## Launch webui.sh --api (or webui-user.bat) in a fresh terminal window.
func _start_a1111_server() -> void:
	var os_name := OS.get_name()
	if os_name == "Windows":
		_show_message(
			"Windows users: open the AUTOMATIC1111 install folder and double-click"
			+ " webui-user.bat. Add --api to the COMMANDLINE_ARGS line first."
		)
		return

	var home := OS.get_environment("HOME")
	var webui := home.path_join("stable-diffusion-webui/webui.sh")
	if not FileAccess.file_exists(webui):
		_show_message(
			"Could not find %s\n\nRun the installer first (Install Local SD…)" % webui
		)
		return
	OS.execute("chmod", ["+x", webui])

	# Build a command that cd's into the install dir then runs webui with --api.
	# We unset VIRTUAL_ENV / PYTHONHOME so webui.sh can build its own venv.
	# (If it inherits a parent venv, it skips its own venv and falls back to
	# /usr/bin/python, which on Debian/Ubuntu blocks `pip install` under
	# PEP 668 with "externally-managed-environment".)
	# --nowebui: API-only mode — skips the Gradio web UI so no browser window
	# pops up. The plugin only ever talks to the JSON API on port 7860.
	# --nowebui defaults to port 7861 so we pin --port 7860 to match the backend.
	var shell_cmd := "unset VIRTUAL_ENV PYTHONHOME; cd ~/stable-diffusion-webui && ./webui.sh --nowebui --api --port 7860; echo; echo '[server stopped — press Enter to close]'; read"

	var pid := -1
	if os_name == "Linux":
		for term in [
			["x-terminal-emulator", ["-e", "bash", "-lc", shell_cmd]],
			["gnome-terminal", ["--", "bash", "-lc", shell_cmd]],
			["konsole", ["-e", "bash", "-lc", shell_cmd]],
			["xfce4-terminal", ["-e", "bash -lc '%s'" % shell_cmd.replace("'", "'\\''")]],
			["xterm", ["-hold", "-e", "bash", "-lc", shell_cmd]],
		]:
			pid = OS.create_process(term[0], term[1])
			if pid > 0:
				break
	elif os_name == "macOS":
		# osascript opens a new Terminal.app window and runs the command.
		var applescript := 'tell application "Terminal" to do script "%s"' % shell_cmd.replace('"', '\\"')
		pid = OS.create_process("osascript", ["-e", applescript])

	if pid <= 0:
		_show_message(
			"Could not open a terminal automatically. Run this in a shell:\n\n  %s" % _a1111_start_command()
		)
		return

	_show_message(
		"Server launching in a new terminal.\n\n"
		+ "Wait for the line:\n"
		+ "  Running on local URL:  http://127.0.0.1:7860\n\n"
		+ "Then click 'Test connection' in Settings."
	)


func _show_message(msg: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.dialog_text = msg
	dlg.title = "AI Art"
	dlg.min_size = Vector2(440, 0)
	_view.add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())


# ─── Per-preset prompt defaults (suffix + negative) ──────────────
# The built-in `suffix` / `negative` fields in `_PRESETS` are the factory
# defaults. The user can override them per preset via the gear button next
# to the preset dropdown; overrides are persisted in ProjectSettings under
# `vg/ai_art/preset_overrides/<preset>/{suffix,negative}` and reloaded
# automatically on next launch.

func _preset_override_path(preset_name: String, field: String) -> String:
	# Sanitize preset name to be a safe ProjectSettings key segment.
	var key := preset_name.to_lower()
	var safe := ""
	for c in key:
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			safe += c
		else:
			safe += "_"
	return "%s/%s/%s" % [_SETTINGS_PRESET_OVERRIDE_ROOT, safe, field]

func _get_preset_suffix(preset_name: String, preset: Dictionary) -> String:
	var override_val: String = String(_load_setting(_preset_override_path(preset_name, "suffix"), ""))
	if not override_val.is_empty():
		return override_val
	return String(preset.get("suffix", ""))

func _get_preset_negative(preset_name: String, preset: Dictionary) -> String:
	var override_val: String = String(_load_setting(_preset_override_path(preset_name, "negative"), ""))
	if not override_val.is_empty():
		return override_val
	return String(preset.get("negative", ""))

func _open_preset_defaults_dialog() -> void:
	var idx := _preset_dd.selected
	if idx < 0 or idx >= _preset_dd.item_count:
		return
	var preset_name: String = _preset_dd.get_item_text(idx)
	if not _PRESETS.has(preset_name):
		return
	var preset: Dictionary = _PRESETS[preset_name]
	var factory_suffix: String = String(preset.get("suffix", ""))
	var factory_negative: String = String(preset.get("negative", ""))

	var dlg := AcceptDialog.new()
	dlg.title = "Defaults for: %s" % preset_name
	dlg.min_size = Vector2(640, 420)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dlg.add_child(v)

	var intro := Label.new()
	intro.text = "These are auto-appended to every prompt for this preset. "\
		+ "Edit to taste — leave empty to fall back to the factory default shown below."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(intro)

	v.add_child(HSeparator.new())

	var sl := Label.new(); sl.text = "Style suffix (appended after your prompt):"
	v.add_child(sl)
	var suffix_edit := TextEdit.new()
	suffix_edit.custom_minimum_size = Vector2(0, 90)
	suffix_edit.text = String(_load_setting(_preset_override_path(preset_name, "suffix"), factory_suffix))
	v.add_child(suffix_edit)
	var sf := Label.new()
	sf.text = "Factory: " + factory_suffix
	sf.modulate = Color(0.6, 0.6, 0.65)
	sf.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(sf)

	var nl := Label.new(); nl.text = "Avoid (negative prompt) default:"
	v.add_child(nl)
	var neg_edit := TextEdit.new()
	neg_edit.custom_minimum_size = Vector2(0, 60)
	neg_edit.text = String(_load_setting(_preset_override_path(preset_name, "negative"), factory_negative))
	v.add_child(neg_edit)
	var nf := Label.new()
	nf.text = "Factory: " + factory_negative
	nf.modulate = Color(0.6, 0.6, 0.65)
	nf.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(nf)

	dlg.add_button("Reset to factory", true, "reset")
	dlg.ok_button_text = "Save"

	dlg.custom_action.connect(func(action: StringName):
		if action == "reset":
			suffix_edit.text = factory_suffix
			neg_edit.text = factory_negative
	)
	dlg.confirmed.connect(func():
		# Save overrides only if they differ from the factory; otherwise clear
		# them so future factory tweaks roll forward automatically.
		var s := suffix_edit.text.strip_edges()
		var n := neg_edit.text.strip_edges()
		_save_setting(_preset_override_path(preset_name, "suffix"),
			"" if s == factory_suffix.strip_edges() else s)
		_save_setting(_preset_override_path(preset_name, "negative"),
			"" if n == factory_negative.strip_edges() else n)
		# Refresh placeholder for the negative field if user is on this preset.
		if _negative_edit != null and _negative_edit.text.strip_edges().is_empty():
			_negative_edit.placeholder_text = _get_preset_negative(preset_name, preset)
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	_view.add_child(dlg)
	dlg.popup_centered()


# ─── GPU detection (used to warn before A1111 install) ───────────

## Returns true if an NVIDIA / AMD GPU appears available; false on CPU-only
## boxes. Used to warn the user before they kick off the ~10 GB install
## that A1111 will be painfully slow on CPU.
func _has_gpu() -> bool:
	if OS.get_name() != "Linux":
		# Best-effort: assume Windows/macOS users typically have a GPU. We
		# don't want to false-warn Mac M-series users (Metal works fine).
		return true
	# nvidia-smi exits 0 only when a working NVIDIA driver is present.
	var out: Array = []
	var rc := OS.execute("nvidia-smi", ["-L"], out, true)
	if rc == 0:
		return true
	# Fall back to lspci for AMD / Intel discrete cards.
	out.clear()
	OS.execute("bash", ["-lc", "lspci | grep -iE 'vga|3d|display' | grep -ivE 'integrated|llvmpipe' | head -1"], out, true)
	if out.size() > 0 and not String(out[0]).strip_edges().is_empty():
		# Intel/AMD discrete present — but not necessarily usable for SD.
		# Treat as "maybe GPU" and don't warn.
		return true
	return false


# ─── Settings persistence (ProjectSettings) ──────────────────────

func _load_settings() -> void:
	# Force-create entries so they show up in Project Settings UI.
	for k in [_SETTINGS_BACKEND, _SETTINGS_HF_TOKEN, _SETTINGS_HF_MODEL, _SETTINGS_A1111_URL, _SETTINGS_LAST_PROMPT]:
		if not ProjectSettings.has_setting(k):
			ProjectSettings.set_setting(k, "")
			ProjectSettings.set_initial_value(k, "")
	if not ProjectSettings.has_setting(_SETTINGS_USE_CONTROLNET):
		ProjectSettings.set_setting(_SETTINGS_USE_CONTROLNET, true)
		ProjectSettings.set_initial_value(_SETTINGS_USE_CONTROLNET, true)


func _load_setting(key: String, default_value) -> Variant:
	if ProjectSettings.has_setting(key):
		var v = ProjectSettings.get_setting(key)
		if typeof(v) == TYPE_STRING and String(v).is_empty() and typeof(default_value) == TYPE_STRING:
			return default_value
		return v
	return default_value


func _save_setting(key: String, value) -> void:
	ProjectSettings.set_setting(key, value)
	# Persist on disk so it survives restarts. Failure is non-fatal — the
	# value is still in-memory for this session.
	var err := ProjectSettings.save()
	if err != OK and err != ERR_FILE_CANT_OPEN:
		push_warning("[VG AI Art] Could not persist setting %s (err %d)" % [key, err])
