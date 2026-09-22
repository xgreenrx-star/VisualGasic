# VG samples — small shared modules

| File | Use |
|------|-----|
| `HttpUtil.vg` | GET with retry, day-cache under `user://`, generation token so a restarted load can ignore a stale body |

The file lives in `samples/apps/climatist_poc/HttpUtil.vg` (Godot will not import a script that resolves outside the project). This folder links to that copy. Other projects should copy it in and `Import "HttpUtil.vg"`.
