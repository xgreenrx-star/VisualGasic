# Custom AI providers

Narcea Vibe Code can use user-defined chat providers without editing the plugin.
Built-in providers remain available as presets. Custom entries support
OpenAI-compatible Chat Completions, Anthropic-compatible Messages, and Ollama's
`/api/generate` format.

## Add a provider

1. Open **Narcea Vibe Code** (`Ctrl+Shift+N`).
2. Click the **AI Providers and API Keys** settings button (gear icon).
3. Under **Custom AI providers**, click **Add custom provider**.
4. Enter a display name and choose the API format.
5. Enter the **full chat request endpoint**, including its path. For example:

   | Format | Example endpoint |
   |---|---|
   | OpenAI-compatible | `http://localhost:1234/v1/chat/completions` |
   | Anthropic-compatible | `https://your-service.example/v1/messages` |
   | Ollama | `http://localhost:11434/api/generate` |

   These are format examples, not endorsements or verified hosted services.
   Use the endpoint documented by your service. Nondefault ports and IPv6
   loopback URLs such as `http://[::1]:11434/api/generate` are supported.

6. Enter one or more exact **model IDs**, comma-separated, and a default ID
   from that list. A new model does not need to be in VG's built-in catalog.
7. Enter an API key if needed and check **Require an API key** for services
   that require authentication.
8. Optionally enable **native tool calls** or **PNG image input** only when
   the selected models and service support those features. Native tools are
   supported for the OpenAI/Anthropic formats, not this Ollama adapter.
9. Optionally click **Test connection**, then **Save**.
10. Select the new entry (marked **Custom**) in the provider dropdown.

The connection test sends a small synthetic prompt, not project source,
conversation history or debug captures. It verifies a compatible, nonempty
assistant response, with a 20-second timeout and a 1 MiB response limit.
It can incur an API charge. Adding or saving a provider does not perform the
connection test automatically.

## Model discovery and updates

Manual model IDs work without a discovery endpoint. To enable the existing
model-refresh button, enter a **model discovery path** on the same server:

- OpenAI/Anthropic-compatible: typically `/v1/models`, returning
  `{"data":[{"id":"model-id"}]}`.
- Ollama: typically `/api/tags`, returning
  `{"models":[{"name":"model-id"}]}`.

Use the actual path for your service, including any proxy prefix. Leave it
empty if the service does not offer model discovery. Refresh reports missing,
malformed or failed discovery responses explicitly; it does not erase manual
models. Discovered entries are combined with the manual list. Editing the
provider configuration or key invalidates its discovery cache.

To adopt a new model, edit its manual IDs/default or refresh its catalog.
To replace an obsolete service, edit the endpoint and format, or remove the
old entry and add a new one. Removing an entry clears its saved key and
discovery cache; if it was preferred, VG falls back to built-in Ollama.

## Storage and privacy

Provider definitions and keys live in **Godot Editor Settings**, shared across
projects for the current editor profile. They are not saved in `project.godot`
or included in an exported game. Provider definitions contain no keys; keys
are separate password-masked settings. Password masking is **not encryption**:
protect your editor settings files and do not commit or share them.

HTTPS uses normal certificate verification. HTTP is useful for local servers,
but sends prompts and keys unencrypted; do not use it for an untrusted network.
URLs cannot embed credentials, queries or fragments. OpenAI-compatible and
authenticated Ollama requests use Bearer authentication; Anthropic-compatible
requests use `x-api-key` and the existing Anthropic API version header.

Normal chat and AI repair send their prompts and included context to the
configured endpoint. Choose a service you trust. Custom endpoints do not change
the dedicated OpenAI voice/realtime backends.

## Limits

- This is a chat-provider interface, not a loader for arbitrary agents,
  executables, IDE subscriptions, MCP servers or SDKs.
- OpenAI compatibility here means **Chat Completions**, not the Responses API.
- Ollama compatibility here means **Generate**, not `/api/chat`.
- APIs needing another request schema or authentication mechanism require a
  code adapter. Gemini remains a built-in adapter, not a custom format.
- A compatible schema does not guarantee a model supports tools or images.
  Leave those capabilities unchecked unless verified.
- No cloud-provider availability claim is made by the offline regression tests.

## Regression tests

From the repository root:

```sh
./Godot_v4.6.1-stable_linux.x86_64 --headless --path test_proj \
  --script "$PWD/tests/test_custom_ai_providers.gd"
```

Tests use synthetic data and an owned loopback HTTP server. Additional
editor-only registry/routing checks can be run with `--editor`, but only after
setting `VG_CUSTOM_PROVIDER_TEST_SETTINGS=isolated` and pointing
`XDG_CONFIG_HOME`, `XDG_DATA_HOME` and `XDG_CACHE_HOME` at a disposable profile.
Do not run the editor-only test mode against your normal settings.

The custom runtime tests exit cleanly. Godot's `--editor --script SceneTree`
test mode emits editor shutdown RID/ObjectDB leak diagnostics, including in
the restart-only checks that create no custom UI; those diagnostics are not a
claim that editor-mode leak checking passed.
