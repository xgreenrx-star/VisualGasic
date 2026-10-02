# Upcoming release — copy highlights

Shipped in **5.6.0-beta1** — see `RELEASE_NOTES_v5.6.0-beta1.md` and `docs/showcase/FACEBOOK_VECTOR_CRYPT_5.6.0-beta1.md`.

## Windows JIT (shipped — still collect feedback)

Visual Gasic’s **native JIT** now runs on **Windows x64** (Tier 2 + Tier 3), same as Linux.

- **Default on x86-64 desktop:** hot numeric subs compile to native code after warmup unless `VG_JIT=0`.
- **Still untested in CI:** we do **not** yet publish Windows-vs-GDScript JIT benchmark tables.
- **Ask in every post:** try on Windows hardware; report FPS / correctness / need for `VG_JIT=0`.

## Fast-call path (all platforms)

Documented in [performance.md](../manual/performance.md#fast-call-path): keep hot helpers on **`ByVal` + scalar `As`** types; one **`ByRef`** (or bare parameter) takes the whole procedure off the fast-call path.
