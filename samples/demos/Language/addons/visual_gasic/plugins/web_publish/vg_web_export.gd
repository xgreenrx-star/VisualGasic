@tool
## VG Web Export — Game → Web publishing backend
##
## Generates HTML5 export presets, wrapper HTML pages with Flash-successor
## features (preloader, fullscreen toggle, right-click menu, embed code,
## quality control, background color, scale mode), and game portal–ready
## self-contained packages.
##
## Inspired by the best of Flash (Newgrounds/Kongregate era) without the
## security issues — powered by Godot's HTML5/WebAssembly export.
##
## Moved from plugins/agck/agck_web_export.gd to plugins/web_publish/
## so it can be used independently of AGCK.
extends RefCounted

# ─── Web Export Configuration ────────────────────────────────
## All web-specific settings gathered from the Build tab.
class WebConfig:
	var game_title: String = "My Game"
	var bg_color: Color = Color(0.05, 0.05, 0.08)
	var loading_style: String = "Bar"           # Bar, Spinner, Retro, None
	var loading_color: Color = Color(1.0, 0.82, 0.35)  # AGCK accent gold
	var quality: String = "High"                # Low, Medium, High, Best
	var scale_mode: String = "Fit"              # Fit, Fill, Stretch, Pixel-Perfect
	var fullscreen_button: bool = true
	var right_click_menu: bool = true
	var show_watermark: bool = true             # "Made with VisualGasic" badge
	var canvas_width: int = 640
	var canvas_height: int = 384
	var embed_ready: bool = true                # Generate embed snippet
	var splash_enabled: bool = true
	var splash_duration: float = 1.5
	var icon_path: String = ""                  # Favicon path
	var description: String = ""                # Meta description for SEO/portals


# ─── Preset Generation ──────────────────────────────────────

## Creates or updates the export_presets.cfg to include an HTML5/Web preset.
## Returns true if the preset was successfully written.
static func ensure_web_export_preset() -> bool:
	var presets_path := "res://export_presets.cfg"
	var existing_text := ""
	if FileAccess.file_exists(presets_path):
		var f := FileAccess.open(presets_path, FileAccess.READ)
		if f:
			existing_text = f.get_as_text()
			f.close()

	# Check if a Web preset already exists
	if existing_text.find('"Web"') >= 0 and existing_text.find('platform="Web"') >= 0:
		return true  # Already exists

	# Find the next preset index
	var next_idx := 0
	var regex := RegEx.new()
	regex.compile(r'\[preset\.(\d+)\]')
	var matches := regex.search_all(existing_text)
	for m in matches:
		var idx := m.get_string(1).to_int()
		if idx >= next_idx:
			next_idx = idx + 1

	# Append the Web preset
	var web_preset := """
[preset.%d]

name="Web"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""

[preset.%d.options]

""" % [next_idx, next_idx]

	var fw := FileAccess.open(presets_path, FileAccess.WRITE)
	if not fw:
		push_error("[AGCK Web] Cannot write export_presets.cfg")
		return false
	fw.store_string(existing_text + web_preset)
	fw.close()
	return true


# ─── HTML Wrapper Generation ────────────────────────────────

## Generates the complete wrapper HTML file that hosts the Godot WASM game.
## This replaces Flash's SWF embed approach with modern HTML5 + WebAssembly.
static func generate_wrapper_html(config: WebConfig, wasm_filename: String = "") -> String:
	var safe_title := _esc(config.game_title)
	var bg_hex := "#" + config.bg_color.to_html(false)
	var load_hex := "#" + config.loading_color.to_html(false)

	# Auto-detect the .js filename from the game title
	var js_file := wasm_filename
	if js_file.is_empty():
		js_file = config.game_title.replace(" ", "_").to_lower()

	var html := ""
	html += _html_doctype()
	html += _html_head(safe_title, bg_hex, config)
	html += _html_body(safe_title, bg_hex, load_hex, js_file, config)
	html += "</html>\n"
	return html


## Generates an embeddable HTML snippet for game portals.
static func generate_embed_code(config: WebConfig, hosted_url: String = "") -> String:
	var url := hosted_url if not hosted_url.is_empty() else "./" + config.game_title.replace(" ", "_").to_lower() + ".html"
	var snippet := '<iframe src="%s" width="%d" height="%d" ' % [url, config.canvas_width, config.canvas_height + 40]
	snippet += 'style="border:none; border-radius:8px; box-shadow:0 4px 24px rgba(0,0,0,0.4);" '
	snippet += 'allow="autoplay; fullscreen; gamepad" '
	snippet += 'allowfullscreen></iframe>'
	return snippet


## Generates a simple landing page with the game embedded — like a Newgrounds game page.
static func generate_portal_page(config: WebConfig, game_html_filename: String) -> String:
	var safe_title := _esc(config.game_title)
	var bg_hex := "#" + config.bg_color.to_html(false)
	var load_hex := "#" + config.loading_color.to_html(false)
	var desc := _esc(config.description) if not config.description.is_empty() else "An interactive experience made with VisualGasic"

	return """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="description" content="%s">
<meta property="og:title" content="%s">
<meta property="og:description" content="%s">
<meta property="og:type" content="website">
<title>%s</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: %s;
    color: #e8e6e0;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  .portal-header {
    text-align: center;
    padding: 32px 16px 16px;
  }
  .portal-header h1 {
    font-size: 2em;
    color: %s;
    text-shadow: 0 2px 8px rgba(0,0,0,0.5);
  }
  .portal-header p {
    color: #aaa;
    margin-top: 8px;
    font-size: 0.95em;
  }
  .game-container {
    position: relative;
    margin: 16px auto;
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 8px 32px rgba(0,0,0,0.6);
    background: #000;
  }
  .game-container iframe {
    display: block;
    border: none;
  }
  .portal-footer {
    text-align: center;
    padding: 24px 16px;
    color: #666;
    font-size: 0.85em;
  }
  .portal-footer a {
    color: %s;
    text-decoration: none;
  }
  .embed-section {
    max-width: 700px;
    margin: 16px auto;
    padding: 16px;
    background: rgba(255,255,255,0.05);
    border-radius: 8px;
  }
  .embed-section h3 {
    font-size: 0.9em;
    color: #888;
    margin-bottom: 8px;
  }
  .embed-code {
    background: rgba(0,0,0,0.4);
    padding: 12px;
    border-radius: 6px;
    font-family: 'Courier New', monospace;
    font-size: 0.8em;
    color: #8f8;
    word-break: break-all;
    cursor: pointer;
    user-select: all;
  }
  .embed-code:hover {
    background: rgba(0,0,0,0.6);
  }
</style>
</head>
<body>
  <div class="portal-header">
    <h1>🕹️ %s</h1>
    <p>%s</p>
  </div>
  <div class="game-container">
    <iframe src="%s" width="%d" height="%d"
      allow="autoplay; fullscreen; gamepad" allowfullscreen></iframe>
  </div>
  <div class="embed-section">
    <h3>📋 Embed This Game (click to select)</h3>
    <div class="embed-code" onclick="this.focus(); document.execCommand('selectAll')">
      %s
    </div>
  </div>
  <div class="portal-footer">
    Made with <a href="https://github.com/nicholasgasior/VisualGasic" target="_blank">VisualGasic</a> —
    a Flash successor for interactive content
  </div>
</body>
</html>
""" % [
	desc, safe_title, desc, safe_title,
	bg_hex, load_hex, load_hex,
	safe_title, desc,
	game_html_filename, config.canvas_width, config.canvas_height + 40,
	_esc(generate_embed_code(config, game_html_filename)),
]


# ─── Internal HTML Builders ─────────────────────────────────

static func _html_doctype() -> String:
	return "<!DOCTYPE html>\n<html lang=\"en\">\n"


static func _html_head(title: String, bg_hex: String, config: WebConfig) -> String:
	var desc := _esc(config.description) if not config.description.is_empty() else "Interactive content made with VisualGasic"
	var quality_hint := ""
	match config.quality:
		"Low":
			quality_hint = "image-rendering: pixelated;"
		"Pixel-Perfect":
			quality_hint = "image-rendering: pixelated;"
	return """<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<meta name="description" content="%s">
<meta property="og:title" content="%s">
<meta property="og:description" content="%s">
<title>%s</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body {
    width: 100%%; height: 100%%;
    overflow: hidden;
    background: %s;
    %s
  }
  /* ── Canvas Container ── */
  #game-canvas {
    display: block;
    margin: 0 auto;
    %s
  }
  /* ── Loading Screen (Flash-style preloader) ── */
  #loading-overlay {
    position: fixed;
    inset: 0;
    background: %s;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    z-index: 9999;
    transition: opacity 0.5s ease;
  }
  #loading-overlay.fade-out {
    opacity: 0;
    pointer-events: none;
  }
%s
  /* ── Fullscreen Button ── */
  #fullscreen-btn {
    position: fixed;
    bottom: 8px;
    right: 8px;
    width: 36px; height: 36px;
    background: rgba(255,255,255,0.1);
    border: 1px solid rgba(255,255,255,0.2);
    border-radius: 6px;
    color: #fff;
    font-size: 18px;
    cursor: pointer;
    z-index: 100;
    display: %s;
    align-items: center;
    justify-content: center;
    transition: background 0.2s;
  }
  #fullscreen-btn:hover {
    background: rgba(255,255,255,0.25);
  }
  /* ── Watermark ── */
  #vg-watermark {
    position: fixed;
    bottom: 6px;
    left: 8px;
    font-family: monospace;
    font-size: 10px;
    color: rgba(255,255,255,0.2);
    z-index: 50;
    pointer-events: none;
    display: %s;
  }
  /* ── Right-Click Menu (Flash-inspired) ── */
  #context-menu {
    display: none;
    position: fixed;
    background: rgba(30, 30, 38, 0.95);
    border: 1px solid rgba(255,255,255,0.15);
    border-radius: 6px;
    padding: 4px 0;
    min-width: 180px;
    box-shadow: 0 4px 16px rgba(0,0,0,0.5);
    z-index: 10000;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    font-size: 13px;
    color: #ddd;
  }
  #context-menu .ctx-item {
    padding: 6px 16px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  #context-menu .ctx-item:hover {
    background: rgba(255, 200, 60, 0.15);
    color: #fff;
  }
  #context-menu .ctx-sep {
    height: 1px;
    background: rgba(255,255,255,0.1);
    margin: 4px 8px;
  }
</style>
</head>
""" % [
	desc, title, desc, title,
	bg_hex,
	quality_hint,
	quality_hint,
	bg_hex,
	_loading_css(config),
	"flex" if config.fullscreen_button else "none",
	"block" if config.show_watermark else "none",
]


static func _html_body(title: String, bg_hex: String, load_hex: String, js_file: String, config: WebConfig) -> String:
	var scale_js := _scale_mode_js(config)
	var ctx_menu_js := _context_menu_js(config) if config.right_click_menu else ""
	var fullscreen_js := _fullscreen_js() if config.fullscreen_button else ""
	var splash_js := _splash_js(config) if config.splash_enabled else ""

	return """<body>
  <!-- Loading Overlay (Flash-style preloader) -->
  <div id="loading-overlay">
%s
  </div>

  <!-- Fullscreen Button -->
  <button id="fullscreen-btn" title="Toggle Fullscreen (F11)">⛶</button>

  <!-- Watermark -->
  <div id="vg-watermark">Made with VisualGasic</div>

  <!-- Right-Click Context Menu -->
  <div id="context-menu">
    <div class="ctx-item" onclick="toggleFullscreen()">⛶ Toggle Fullscreen</div>
    <div class="ctx-sep"></div>
    <div class="ctx-item" onclick="window.location.reload()">🔄 Restart</div>
    <div class="ctx-sep"></div>
    <div class="ctx-item" style="color:#888; cursor:default">🕹️ %s</div>
    <div class="ctx-item" style="color:#666; font-size:11px; cursor:default">Made with VisualGasic</div>
  </div>

  <!-- Godot Engine Loader -->
  <canvas id="game-canvas"></canvas>

  <script>
    // ── Configuration ──
    const GAME_TITLE = '%s';
    const CANVAS_W = %d;
    const CANVAS_H = %d;
    const BG_COLOR = '%s';
    const LOAD_COLOR = '%s';

    // ── Loading Progress ──
    let loadingOverlay = document.getElementById('loading-overlay');
    let progressFill = document.getElementById('progress-fill');
    let progressText = document.getElementById('progress-text');

    function updateProgress(current, total) {
      if (!progressFill) return;
      let pct = total > 0 ? Math.min(100, Math.round((current / total) * 100)) : 0;
      progressFill.style.width = pct + '%%';
      if (progressText) progressText.textContent = pct + '%%';
    }

    function hideLoading() {
      if (loadingOverlay) {
        loadingOverlay.classList.add('fade-out');
        setTimeout(() => { loadingOverlay.style.display = 'none'; }, 600);
      }
    }

    // ── Scale Mode (Flash-inspired: showall/noborder/exactfit) ──
%s

    // ── Fullscreen (Flash's Stage.displayState) ──
    function toggleFullscreen() {
      if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen().catch(() => {});
      } else {
        document.exitFullscreen();
      }
    }
%s

    // ── Right-Click Context Menu (Flash's ContextMenu) ──
%s

    // ── Godot Engine Initialization ──
    // The Godot HTML5 export generates a .js loader file.
    // We hook into its progress callbacks for the preloader.
    window.addEventListener('DOMContentLoaded', function() {
      resizeCanvas();
      window.addEventListener('resize', resizeCanvas);

      // Try to initialize Godot engine
      if (typeof Engine !== 'undefined') {
        let engine = new Engine({
          args: [],
          canvasResizePolicy: 0,
          executable: '%s',
          fileSizes: {},
          focusCanvas: true,
          gdextensionLibs: [],
        });
        engine.startGame({
          canvas: document.getElementById('game-canvas'),
          onProgress: function(current, total) {
            updateProgress(current, total);
          },
        }).then(function() {
          hideLoading();
        }).catch(function(err) {
          console.error('Godot engine error:', err);
          if (progressText) progressText.textContent = 'Error loading game';
        });
      } else {
        // Fallback: look for the auto-generated Godot loader
        hideLoading();
      }
    });

%s
  </script>
</body>
""" % [
	_loading_html(config, load_hex),
	title,
	title.replace("'", "\\'"),
	config.canvas_width,
	config.canvas_height,
	bg_hex,
	load_hex,
	scale_js,
	fullscreen_js,
	ctx_menu_js,
	js_file.replace("'", "\\'"),
	splash_js,
]


# ─── Loading Screen Styles (Flash's preloader tradition) ────

static func _loading_css(config: WebConfig) -> String:
	var load_hex := "#" + config.loading_color.to_html(false)
	match config.loading_style:
		"Bar":
			return """  /* Loading Bar */
  .load-title { font-family: monospace; font-size: 18px; color: %s; margin-bottom: 24px; text-shadow: 0 0 8px %s40; }
  .progress-bar { width: 280px; height: 8px; background: rgba(255,255,255,0.1); border-radius: 4px; overflow: hidden; }
  .progress-fill { height: 100%%; width: 0%%; background: %s; border-radius: 4px; transition: width 0.15s ease; }
  .progress-pct { font-family: monospace; font-size: 12px; color: rgba(255,255,255,0.5); margin-top: 8px; }
""" % [load_hex, load_hex, load_hex]
		"Spinner":
			return """  /* Spinner */
  .load-title { font-family: monospace; font-size: 18px; color: %s; margin-bottom: 24px; }
  @keyframes spin { to { transform: rotate(360deg); } }
  .spinner { width: 40px; height: 40px; border: 3px solid rgba(255,255,255,0.1); border-top-color: %s; border-radius: 50%%; animation: spin 0.8s linear infinite; }
  .progress-pct { font-family: monospace; font-size: 12px; color: rgba(255,255,255,0.5); margin-top: 16px; }
""" % [load_hex, load_hex]
		"Retro":
			return """  /* Retro (Flash-era pixel style) */
  .load-title { font-family: 'Courier New', monospace; font-size: 16px; color: %s; margin-bottom: 16px; letter-spacing: 2px; text-transform: uppercase; }
  .progress-bar { width: 240px; height: 16px; background: #111; border: 2px solid %s; image-rendering: pixelated; }
  .progress-fill { height: 100%%; width: 0%%; background: %s; transition: width 0.1s steps(20); }
  .progress-pct { font-family: 'Courier New', monospace; font-size: 14px; color: %s; margin-top: 8px; letter-spacing: 4px; }
""" % [load_hex, load_hex, load_hex, load_hex]
		_:  # "None"
			return "  /* No loading screen */\n"


static func _loading_html(config: WebConfig, load_hex: String) -> String:
	match config.loading_style:
		"Bar":
			return """    <div class="load-title">🕹️ Loading…</div>
    <div class="progress-bar">
      <div class="progress-fill" id="progress-fill"></div>
    </div>
    <div class="progress-pct" id="progress-text">0%%</div>"""
		"Spinner":
			return """    <div class="load-title">🕹️ Loading…</div>
    <div class="spinner"></div>
    <div class="progress-pct" id="progress-text">0%%</div>"""
		"Retro":
			return """    <div class="load-title">▶ LOADING ◀</div>
    <div class="progress-bar">
      <div class="progress-fill" id="progress-fill"></div>
    </div>
    <div class="progress-pct" id="progress-text">0%%</div>"""
		_:
			return "    <!-- No loading screen -->"


# ─── Scale Mode JavaScript (Flash's Stage.scaleMode) ────────

static func _scale_mode_js(config: WebConfig) -> String:
	match config.scale_mode:
		"Fit":  # Flash's "showAll" — fit within window, preserve aspect ratio
			return """    function resizeCanvas() {
      let canvas = document.getElementById('game-canvas');
      if (!canvas) return;
      let ww = window.innerWidth, wh = window.innerHeight;
      let ratio = Math.min(ww / CANVAS_W, wh / CANVAS_H);
      canvas.style.width = Math.floor(CANVAS_W * ratio) + 'px';
      canvas.style.height = Math.floor(CANVAS_H * ratio) + 'px';
      canvas.style.position = 'absolute';
      canvas.style.left = Math.floor((ww - CANVAS_W * ratio) / 2) + 'px';
      canvas.style.top = Math.floor((wh - CANVAS_H * ratio) / 2) + 'px';
      canvas.width = CANVAS_W;
      canvas.height = CANVAS_H;
    }"""
		"Fill":  # Flash's "noBorder" — fill window, crop edges
			return """    function resizeCanvas() {
      let canvas = document.getElementById('game-canvas');
      if (!canvas) return;
      let ww = window.innerWidth, wh = window.innerHeight;
      let ratio = Math.max(ww / CANVAS_W, wh / CANVAS_H);
      canvas.style.width = Math.floor(CANVAS_W * ratio) + 'px';
      canvas.style.height = Math.floor(CANVAS_H * ratio) + 'px';
      canvas.style.position = 'absolute';
      canvas.style.left = Math.floor((ww - CANVAS_W * ratio) / 2) + 'px';
      canvas.style.top = Math.floor((wh - CANVAS_H * ratio) / 2) + 'px';
      canvas.width = CANVAS_W;
      canvas.height = CANVAS_H;
    }"""
		"Stretch":  # Flash's "exactFit" — stretch to fill, ignore aspect ratio
			return """    function resizeCanvas() {
      let canvas = document.getElementById('game-canvas');
      if (!canvas) return;
      canvas.style.width = '100vw';
      canvas.style.height = '100vh';
      canvas.style.position = 'absolute';
      canvas.style.left = '0';
      canvas.style.top = '0';
      canvas.width = CANVAS_W;
      canvas.height = CANVAS_H;
    }"""
		"Pixel-Perfect":  # No scaling — 1:1 pixels, centered
			return """    function resizeCanvas() {
      let canvas = document.getElementById('game-canvas');
      if (!canvas) return;
      let ww = window.innerWidth, wh = window.innerHeight;
      canvas.style.width = CANVAS_W + 'px';
      canvas.style.height = CANVAS_H + 'px';
      canvas.style.position = 'absolute';
      canvas.style.left = Math.floor((ww - CANVAS_W) / 2) + 'px';
      canvas.style.top = Math.floor((wh - CANVAS_H) / 2) + 'px';
      canvas.width = CANVAS_W;
      canvas.height = CANVAS_H;
      canvas.style.imageRendering = 'pixelated';
    }"""
		_:
			return """    function resizeCanvas() {
      let canvas = document.getElementById('game-canvas');
      if (!canvas) return;
      canvas.width = CANVAS_W;
      canvas.height = CANVAS_H;
    }"""


# ─── Fullscreen JavaScript ──────────────────────────────────

static func _fullscreen_js() -> String:
	return """
    // Fullscreen button handler
    document.getElementById('fullscreen-btn').addEventListener('click', toggleFullscreen);
    // F11 key handler
    document.addEventListener('keydown', function(e) {
      if (e.key === 'F11') {
        e.preventDefault();
        toggleFullscreen();
      }
    });
    // Update button icon on fullscreen change
    document.addEventListener('fullscreenchange', function() {
      let btn = document.getElementById('fullscreen-btn');
      btn.textContent = document.fullscreenElement ? '⛶' : '⛶';
      btn.title = document.fullscreenElement ? 'Exit Fullscreen (F11)' : 'Toggle Fullscreen (F11)';
    });"""


# ─── Right-Click Context Menu JavaScript ────────────────────

static func _context_menu_js(config: WebConfig) -> String:
	return """
    // Custom right-click menu (replaces browser default, like Flash's ContextMenu)
    let ctxMenu = document.getElementById('context-menu');
    document.addEventListener('contextmenu', function(e) {
      e.preventDefault();
      ctxMenu.style.display = 'block';
      // Position near cursor, but keep on-screen
      let x = Math.min(e.clientX, window.innerWidth - 200);
      let y = Math.min(e.clientY, window.innerHeight - 150);
      ctxMenu.style.left = x + 'px';
      ctxMenu.style.top = y + 'px';
    });
    document.addEventListener('click', function() {
      ctxMenu.style.display = 'none';
    });
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') ctxMenu.style.display = 'none';
    });"""


# ─── Splash Screen JavaScript ───────────────────────────────

static func _splash_js(config: WebConfig) -> String:
	var dur_ms := int(config.splash_duration * 1000)
	return """
    // Splash screen timeout (auto-hide after game loads)
    setTimeout(function() {
      hideLoading();
    }, %d);""" % dur_ms


# ─── HTML Entity Escaping ───────────────────────────────────

static func _esc(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;").replace("'", "&#39;")


# ─── Full Export Pipeline ───────────────────────────────────

## Runs the complete web export pipeline:
## 1. Ensure HTML5 export preset exists
## 2. Generate wrapper HTML with preloader + features
## 3. Generate portal page with embed code
## 4. Optionally run Godot's --export-release for Web
##
## Returns a result Dictionary with { ok, output_dir, files, embed_code }.
static func publish_to_web(config: WebConfig, output_dir: String, run_export: bool = false, log_fn: Callable = Callable()) -> Dictionary:
	var result := {"ok": false, "output_dir": output_dir, "files": [], "embed_code": ""}

	if not output_dir.ends_with("/"):
		output_dir += "/"

	var safe_name := config.game_title.replace(" ", "_").replace("/", "_").replace("\\", "_")
	if safe_name.is_empty():
		safe_name = "game"

	# ── Step 1: Ensure output directory ──
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)
	_log(log_fn, "[color=#55ccff]🌐 Publishing to Web: " + output_dir + "[/color]")

	# ── Step 2: Ensure export preset ──
	if not ensure_web_export_preset():
		_log(log_fn, "[color=#ff4444]✗ Failed to create Web export preset[/color]")
		return result
	_log(log_fn, "[color=#8f8]  ✓ Web export preset ready[/color]")

	# ── Step 3: Generate wrapper HTML ──
	var wrapper_html := generate_wrapper_html(config, safe_name)
	var wrapper_path := output_dir + safe_name + ".html"
	var wf := FileAccess.open(wrapper_path, FileAccess.WRITE)
	if wf:
		wf.store_string(wrapper_html)
		wf.close()
		result["files"].append(wrapper_path)
		_log(log_fn, "[color=#8f8]  ✓ Generated wrapper HTML: " + wrapper_path + "[/color]")
	else:
		_log(log_fn, "[color=#ff4444]✗ Failed to write " + wrapper_path + "[/color]")
		return result

	# ── Step 4: Generate portal/landing page ──
	var portal_html := generate_portal_page(config, safe_name + ".html")
	var portal_path := output_dir + "index.html"
	var pf := FileAccess.open(portal_path, FileAccess.WRITE)
	if pf:
		pf.store_string(portal_html)
		pf.close()
		result["files"].append(portal_path)
		_log(log_fn, "[color=#8f8]  ✓ Generated portal page: " + portal_path + "[/color]")
	else:
		_log(log_fn, "[color=#ffaa33]⚠ Could not write portal page (non-fatal)[/color]")

	# ── Step 5: Generate embed code ──
	var embed_code := generate_embed_code(config)
	result["embed_code"] = embed_code
	# Save embed snippet to a file for easy copy
	var embed_path := output_dir + "embed_code.txt"
	var ef := FileAccess.open(embed_path, FileAccess.WRITE)
	if ef:
		ef.store_string("<!-- Embed code for " + config.game_title + " -->\n")
		ef.store_string("<!-- Paste this into any HTML page to embed the game -->\n\n")
		ef.store_string(embed_code + "\n")
		ef.close()
		result["files"].append(embed_path)
		_log(log_fn, "[color=#8f8]  ✓ Embed code saved: " + embed_path + "[/color]")

	# ── Step 6: Run Godot export (optional) ──
	if run_export:
		_log(log_fn, "[color=#55ccff]📦 Running Godot HTML5 export…[/color]")
		var export_path := output_dir + safe_name + ".html"
		var godot_path := OS.get_executable_path()
		var args := PackedStringArray([
			"--headless",
			"--export-release",
			"Web",
			export_path,
		])
		_log(log_fn, "[color=#aaa]Running: " + godot_path + " " + " ".join(args) + "[/color]")
		var output := []
		var exit_code := OS.execute(godot_path, args, output, true, false)
		if exit_code == 0:
			_log(log_fn, "[color=#8f8]  ✓ Godot HTML5 export complete[/color]")
		else:
			var err_text := "\n".join(output) if output.size() > 0 else "Unknown error"
			_log(log_fn, "[color=#ffaa33]⚠ Godot export returned code %d: %s[/color]" % [exit_code, err_text])
			_log(log_fn, "[color=#aaa]   The wrapper HTML and portal page are still valid.[/color]")
			_log(log_fn, "[color=#aaa]   You may need to install Web export templates in Godot.[/color]")

	# ── Step 7: Summary ──
	_log(log_fn, "")
	_log(log_fn, "[color=#ffcc55]═══════════════════════════════════════════[/color]")
	_log(log_fn, "[color=#ffcc55]  🌐 Web Publish Complete![/color]")
	_log(log_fn, "[color=#aaa]  • Game page:  " + output_dir + safe_name + ".html[/color]")
	_log(log_fn, "[color=#aaa]  • Portal:     " + output_dir + "index.html[/color]")
	_log(log_fn, "[color=#aaa]  • Embed code: " + output_dir + "embed_code.txt[/color]")
	_log(log_fn, "[color=#aaa]  • Deploy: upload the entire folder to any web server[/color]")
	_log(log_fn, "[color=#ffcc55]═══════════════════════════════════════════[/color]")

	result["ok"] = true
	return result


static func _log(fn: Callable, msg: String) -> void:
	if fn.is_valid():
		fn.call(msg)
	print("[AGCK Web] ", msg.replace("[color=#", "").replace("[/color]", "").replace("]", ""))
