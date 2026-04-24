"""Graphical installer for VisualGasic (Tkinter wizard).

Launched by bootstrap_vg.py when --gui is passed (which is the default when
the AppImage / NSIS shim is double-clicked).  Everything the CLI flags
expose is available as a form field here, so a novice user can just click
through sensible defaults.

The wizard is intentionally a single Tk module using only stdlib; it re-
uses the install engine in bootstrap_vg as plain function calls so we
don't shell out to a second Python process.
"""

from __future__ import annotations

import os
import queue
import sys
import threading
import tkinter as tk
import traceback
from pathlib import Path
from tkinter import filedialog, messagebox, ttk
from typing import Any

# bootstrap_vg is a sibling script; import it for the install logic.
_THIS_DIR = Path(__file__).resolve().parent
if str(_THIS_DIR) not in sys.path:
    sys.path.insert(0, str(_THIS_DIR))
import bootstrap_vg as bvg  # noqa: E402


# ── Tk variable containers ─────────────────────────────────────────────

class _InstallOptions:
    """Mutable holder mirroring argparse.Namespace but built from the GUI."""

    def __init__(self) -> None:
        self.offline: Path | None = None
        self.project_dir: Path = bvg.default_project_parent() / "MyFirstGame"
        self.display_name: str = "My First Game"
        self.godot_version: str = bvg.GODOT_VERSION_DEFAULT
        self.vg_tag: str | None = None
        self.no_launcher: bool = False
        self.no_file_assoc: bool = False
        self.skip_checksum: bool = False
        self.launch: bool = True
        self.include_prereleases: bool = False
        # AI keys
        self.with_ai_keys: bool = False
        self.openai_key: str = ""
        self.claude_key: str = ""
        self.gemini_key: str = ""


# ── Worker thread that runs the install and streams log lines ───────────

class _InstallWorker(threading.Thread):
    def __init__(self, opts: _InstallOptions, log_queue: "queue.Queue[Any]") -> None:
        super().__init__(daemon=True)
        self.opts = opts
        self.q = log_queue
        self.ok: bool | None = None

    def run(self) -> None:
        # Redirect bvg's info/warn/die output into our queue by monkey-patching
        # the print-ish helpers. They're module-level so assignment sticks for
        # the duration of this call.
        q = self.q

        def _emit(prefix: str, msg: str) -> None:
            q.put(("log", f"{prefix}{msg}"))

        orig_info = bvg.info
        orig_warn = bvg.warn
        orig_die = bvg.die

        bvg.info = lambda msg: _emit("  ", str(msg))       # type: ignore[assignment]
        bvg.warn = lambda msg: _emit("⚠  ", str(msg))       # type: ignore[assignment]

        class _DieError(RuntimeError):
            pass

        def _die(msg: str, code: int = 1) -> None:
            raise _DieError(str(msg))

        bvg.die = _die  # type: ignore[assignment]

        try:
            self._run_install()
            self.ok = True
            q.put(("done", "VisualGasic is ready."))
        except _DieError as e:
            self.ok = False
            q.put(("error", str(e)))
        except Exception as e:  # pragma: no cover - defensive
            self.ok = False
            q.put(("error", f"{type(e).__name__}: {e}\n\n{traceback.format_exc()}"))
        finally:
            bvg.info = orig_info      # type: ignore[assignment]
            bvg.warn = orig_warn      # type: ignore[assignment]
            bvg.die = orig_die        # type: ignore[assignment]

    def _run_install(self) -> None:
        o = self.opts
        q = self.q

        q.put(("log", f"Platform:      {bvg.platform.system()} {bvg.platform.machine()}"))
        q.put(("log", f"Godot version: {o.godot_version}"))
        q.put(("log", f"Project dir:   {o.project_dir}"))
        q.put(("log", ""))

        q.put(("step", "Installing VisualGasic addon..."))
        addon_dir, _ = bvg.install_vg_addon(o.offline, o.vg_tag)

        q.put(("step", f"Installing Godot {o.godot_version}..."))
        godot_bin = bvg.install_godot(o.godot_version, o.offline, o.skip_checksum)

        q.put(("step", "Scaffolding project..."))
        project_dir = bvg.scaffold_project(o.project_dir, o.display_name, addon_dir)

        q.put(("step", "Writing launcher and shortcuts..."))
        launcher = bvg.write_launcher(godot_bin, project_dir)
        if not o.no_launcher:
            system = bvg.platform.system()
            if system == "Linux":
                bvg.write_linux_desktop_entry(launcher, project_dir,
                                              register_mime=not o.no_file_assoc)
            elif system == "Windows":
                bvg.write_windows_shortcut(launcher, project_dir)
                if not o.no_file_assoc:
                    bvg.register_windows_file_association(launcher)

        if o.with_ai_keys and (o.openai_key or o.claude_key or o.gemini_key):
            q.put(("step", "Writing AI API keys..."))
            keys = {"openai": o.openai_key, "claude": o.claude_key, "gemini": o.gemini_key}
            bvg.write_godot_ai_keys(o.display_name, keys)

        if o.launch:
            q.put(("step", "Launching VisualGasic IDE..."))
            try:
                bvg.subprocess.Popen([str(launcher)])
            except Exception as e:
                q.put(("log", f"(could not auto-launch: {e}; open '{launcher}' manually)"))


# ── GUI ────────────────────────────────────────────────────────────────

class InstallerApp:
    """Single-window installer with a 'configure → install → done' flow."""

    PAD = 8

    def __init__(self, root: tk.Tk, offline: Path | None = None,
                 initial: _InstallOptions | None = None) -> None:
        self.root = root
        self.opts = initial or _InstallOptions()
        if offline is not None:
            self.opts.offline = offline

        root.title("VisualGasic Installer")
        root.geometry("620x600")
        root.minsize(560, 520)

        self._build_layout()
        self._populate_godot_versions()

    # ── Layout ─────────────────────────────────────────────────────────

    def _build_layout(self) -> None:
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill="both", expand=True, padx=self.PAD, pady=self.PAD)

        self.config_frame = ttk.Frame(self.notebook)
        self.progress_frame = ttk.Frame(self.notebook)
        self.notebook.add(self.config_frame, text="1. Options")
        self.notebook.add(self.progress_frame, text="2. Install")
        # Disable click-switching; we advance programmatically.
        self.notebook.tab(1, state="disabled")

        self._build_config_page(self.config_frame)
        self._build_progress_page(self.progress_frame)

    def _build_config_page(self, parent: ttk.Frame) -> None:
        # Header
        ttk.Label(parent, text="Welcome to VisualGasic",
                  font=("TkDefaultFont", 14, "bold")).pack(anchor="w",
                                                           padx=self.PAD, pady=(self.PAD, 0))
        ttk.Label(parent,
                  text="This will install Godot, the VisualGasic plugin, "
                       "and a starter project on your computer.",
                  wraplength=560, justify="left").pack(anchor="w", padx=self.PAD,
                                                      pady=(0, self.PAD))

        # ── Godot version ─────────────────────────────────────────────
        godot_box = ttk.LabelFrame(parent, text="Godot version")
        godot_box.pack(fill="x", padx=self.PAD, pady=self.PAD)

        self.version_var = tk.StringVar(value=self.opts.godot_version)
        self.version_combo = ttk.Combobox(godot_box, textvariable=self.version_var,
                                          state="readonly", width=32)
        self.version_combo.pack(side="left", padx=self.PAD, pady=self.PAD)

        self.prerelease_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(godot_box, text="Include beta / rc builds",
                        variable=self.prerelease_var,
                        command=self._populate_godot_versions
                        ).pack(side="left", padx=self.PAD)

        # ── Project ───────────────────────────────────────────────────
        proj_box = ttk.LabelFrame(parent, text="Starter project")
        proj_box.pack(fill="x", padx=self.PAD, pady=self.PAD)
        proj_box.columnconfigure(1, weight=1)

        ttk.Label(proj_box, text="Name:").grid(row=0, column=0, sticky="w",
                                               padx=self.PAD, pady=4)
        self.name_var = tk.StringVar(value=self.opts.display_name)
        ttk.Entry(proj_box, textvariable=self.name_var
                  ).grid(row=0, column=1, columnspan=2, sticky="ew", padx=self.PAD, pady=4)

        ttk.Label(proj_box, text="Folder:").grid(row=1, column=0, sticky="w",
                                                 padx=self.PAD, pady=4)
        self.dir_var = tk.StringVar(value=str(self.opts.project_dir))
        ttk.Entry(proj_box, textvariable=self.dir_var
                  ).grid(row=1, column=1, sticky="ew", padx=self.PAD, pady=4)
        ttk.Button(proj_box, text="Browse...", command=self._pick_dir
                   ).grid(row=1, column=2, padx=self.PAD, pady=4)

        # ── AI keys (optional, collapsed by default) ──────────────────
        ai_box = ttk.LabelFrame(parent, text="AI Coding Assistant keys (optional)")
        ai_box.pack(fill="x", padx=self.PAD, pady=self.PAD)

        self.ai_enabled = tk.BooleanVar(value=False)
        ttk.Checkbutton(ai_box, text="Set up AI keys now (you can also add them later from the IDE)",
                        variable=self.ai_enabled,
                        command=self._toggle_ai_fields).pack(anchor="w", padx=self.PAD, pady=4)

        self.ai_fields = ttk.Frame(ai_box)
        self.ai_fields.columnconfigure(1, weight=1)
        self.openai_var = tk.StringVar()
        self.claude_var = tk.StringVar()
        self.gemini_var = tk.StringVar()
        for i, (label, var) in enumerate([("OpenAI:", self.openai_var),
                                          ("Claude:", self.claude_var),
                                          ("Gemini:", self.gemini_var)]):
            ttk.Label(self.ai_fields, text=label).grid(row=i, column=0, sticky="w",
                                                      padx=self.PAD, pady=2)
            ttk.Entry(self.ai_fields, textvariable=var, show="•"
                      ).grid(row=i, column=1, sticky="ew", padx=self.PAD, pady=2)

        # ── Options ───────────────────────────────────────────────────
        opt_box = ttk.LabelFrame(parent, text="Options")
        opt_box.pack(fill="x", padx=self.PAD, pady=self.PAD)

        self.shortcut_var = tk.BooleanVar(value=True)
        self.assoc_var = tk.BooleanVar(value=True)
        self.launch_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(opt_box, text="Create desktop / Start Menu shortcut",
                        variable=self.shortcut_var).pack(anchor="w", padx=self.PAD)
        ttk.Checkbutton(opt_box, text="Register .vg files to open in VisualGasic",
                        variable=self.assoc_var).pack(anchor="w", padx=self.PAD)
        ttk.Checkbutton(opt_box, text="Launch the IDE when install finishes",
                        variable=self.launch_var).pack(anchor="w", padx=self.PAD)

        # ── Buttons ───────────────────────────────────────────────────
        btns = ttk.Frame(parent)
        btns.pack(fill="x", padx=self.PAD, pady=self.PAD)
        ttk.Button(btns, text="Cancel", command=self.root.destroy).pack(side="right")
        ttk.Button(btns, text="Install", command=self._start_install,
                   style="Accent.TButton").pack(side="right", padx=self.PAD)

    def _build_progress_page(self, parent: ttk.Frame) -> None:
        self.step_label = ttk.Label(parent, text="", font=("TkDefaultFont", 11, "bold"))
        self.step_label.pack(anchor="w", padx=self.PAD, pady=(self.PAD, 4))

        self.progress = ttk.Progressbar(parent, mode="indeterminate")
        self.progress.pack(fill="x", padx=self.PAD, pady=(0, self.PAD))

        self.log = tk.Text(parent, height=18, wrap="word", state="disabled",
                           font=("TkFixedFont", 9))
        scroll = ttk.Scrollbar(parent, orient="vertical", command=self.log.yview)
        self.log.configure(yscrollcommand=scroll.set)
        self.log.pack(side="left", fill="both", expand=True, padx=(self.PAD, 0), pady=self.PAD)
        scroll.pack(side="left", fill="y", padx=(0, self.PAD), pady=self.PAD)

        self.finish_frame = ttk.Frame(self.root)
        self.finish_label = ttk.Label(self.finish_frame, text="",
                                      font=("TkDefaultFont", 11, "bold"))
        self.finish_label.pack(side="left", padx=self.PAD)
        ttk.Button(self.finish_frame, text="Close", command=self.root.destroy
                   ).pack(side="right", padx=self.PAD, pady=self.PAD)

    # ── Handlers ───────────────────────────────────────────────────────

    def _pick_dir(self) -> None:
        initial = Path(self.dir_var.get()).parent
        chosen = filedialog.askdirectory(initialdir=str(initial),
                                         title="Choose a folder for your project")
        if chosen:
            # Preserve "MyFirstGame" style leaf if user picks a parent dir.
            leaf = Path(self.dir_var.get()).name
            self.dir_var.set(str(Path(chosen) / leaf))

    def _toggle_ai_fields(self) -> None:
        if self.ai_enabled.get():
            self.ai_fields.pack(fill="x", padx=self.PAD, pady=4)
        else:
            self.ai_fields.pack_forget()

    def _populate_godot_versions(self) -> None:
        def worker() -> None:
            try:
                versions = bvg.list_supported_godot_versions(
                    include_prereleases=self.prerelease_var.get())
            except Exception:
                versions = [bvg.GODOT_VERSION_DEFAULT]

            def apply() -> None:
                self.version_combo["values"] = versions
                if self.version_var.get() not in versions:
                    self.version_var.set(bvg.GODOT_VERSION_DEFAULT
                                         if bvg.GODOT_VERSION_DEFAULT in versions
                                         else versions[0])

            self.root.after(0, apply)

        threading.Thread(target=worker, daemon=True).start()

    # ── Install ────────────────────────────────────────────────────────

    def _collect_options(self) -> _InstallOptions | None:
        o = _InstallOptions()
        o.offline = self.opts.offline
        o.godot_version = self.version_var.get().strip() or bvg.GODOT_VERSION_DEFAULT
        try:
            o.godot_version = bvg.validate_godot_version(o.godot_version)
        except SystemExit:
            messagebox.showerror("Invalid Godot version",
                                 f"{o.godot_version} is not a supported Godot version.")
            return None

        o.display_name = self.name_var.get().strip() or "My First Game"
        o.project_dir = Path(self.dir_var.get().strip()).expanduser()
        if not o.project_dir.name:
            messagebox.showerror("Invalid folder", "Please choose a project folder.")
            return None

        o.no_launcher = not self.shortcut_var.get()
        o.no_file_assoc = not self.assoc_var.get()
        o.launch = self.launch_var.get()

        if self.ai_enabled.get():
            o.with_ai_keys = True
            o.openai_key = self.openai_var.get().strip()
            o.claude_key = self.claude_var.get().strip()
            o.gemini_key = self.gemini_var.get().strip()

        return o

    def _start_install(self) -> None:
        opts = self._collect_options()
        if opts is None:
            return

        # Switch to progress tab
        self.notebook.tab(1, state="normal")
        self.notebook.select(1)
        self.notebook.tab(0, state="disabled")
        self.progress.start(12)

        self.q: "queue.Queue[Any]" = queue.Queue()
        self.worker = _InstallWorker(opts, self.q)
        self.worker.start()
        self.root.after(80, self._drain_log)

    def _drain_log(self) -> None:
        try:
            while True:
                kind, payload = self.q.get_nowait()
                if kind == "log":
                    self._append_log(payload + "\n")
                elif kind == "step":
                    self.step_label.config(text=payload)
                    self._append_log(f"\n▶ {payload}\n")
                elif kind == "done":
                    self._finish(success=True, msg=payload)
                    return
                elif kind == "error":
                    self._finish(success=False, msg=payload)
                    return
        except queue.Empty:
            pass
        if self.worker.is_alive():
            self.root.after(120, self._drain_log)
        else:
            # Worker stopped without sending a terminal event (shouldn't happen).
            self._finish(success=bool(self.worker.ok), msg="Finished.")

    def _append_log(self, text: str) -> None:
        self.log.configure(state="normal")
        self.log.insert("end", text)
        self.log.see("end")
        self.log.configure(state="disabled")

    def _finish(self, success: bool, msg: str) -> None:
        self.progress.stop()
        self.progress.configure(mode="determinate", value=100 if success else 0)
        if success:
            self.step_label.config(text="✅ VisualGasic is ready to go")
            self.finish_label.config(text="Install complete.  You can close this window.")
        else:
            self.step_label.config(text="❌ Install failed")
            self.finish_label.config(text="Install failed — see the log above.")
            self._append_log(f"\n✗ {msg}\n")
        self.finish_frame.pack(fill="x", padx=self.PAD, pady=self.PAD)


# ── Entry point ───────────────────────────────────────────────────────

def run(offline: Path | None = None) -> int:
    """Launch the GUI. Returns process exit code (0 on user close)."""
    try:
        root = tk.Tk()
    except tk.TclError as e:
        print(f"Cannot open the graphical installer: {e}", file=sys.stderr)
        print("Re-run with the command-line flags instead; see --help.", file=sys.stderr)
        return 2

    # Try to use a clam-ish theme that looks OK on all platforms.
    try:
        ttk.Style().theme_use("clam")
    except tk.TclError:
        pass

    InstallerApp(root, offline=offline)
    root.mainloop()
    return 0


if __name__ == "__main__":
    # Allow direct launch for testing.
    off = None
    if len(sys.argv) > 1 and sys.argv[1] == "--offline" and len(sys.argv) > 2:
        off = Path(sys.argv[2])
    sys.exit(run(offline=off))
