# Browser demos (secondary)

These are optional HTML5 exports — not the main product download. They exist to try Visual Gasic + WASM without installing Godot.

| Path | What it is |
|------|------------|
| [climatist/](climatist/index.html) | James weather POC (Now / Pattern / Discussion). NWS may be limited in the browser; desktop Godot is the reference. |

To rebuild from the repo root:

```bash
bash scripts/publish_climatist_web_to_website.sh
```

Then commit the updated `play/climatist/` folder if you want GitHub Pages to serve the new build.

**GitHub Pages:** static hosting does not send COOP/COEP headers, which GDExtension WASM needs. The publish script adds [coi-serviceworker](https://github.com/gzuidhof/coi-serviceworker) — the first visit may **reload once**, then a progress bar at the bottom should advance (~45 MB WASM on first download). The Godot logo splash is stripped in `patch_godot_web_github_pages.py`.

If it hangs or feels stuck: DevTools → Application → Service Workers → Unregister, then hard refresh (Ctrl+Shift+R). Or clear site data for `github.io` and load again. Local testing with `scripts/serve_web_export.py` does not need the service worker.
