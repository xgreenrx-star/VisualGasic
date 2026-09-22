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
