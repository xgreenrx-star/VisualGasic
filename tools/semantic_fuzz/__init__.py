"""VisualGasic semantic fuzz — Phase 1 typed IR, reference model, campaign."""

SCHEMA_VERSION = 1
GENERATOR_VERSION = 1
# v2: ParamSpec ByRef/ByVal, early-return stops subsequent stmts, call frames.
# v3: source_modules multi-file bundles; path_module_key; bound-run contracts.
REFERENCE_VERSION = 3
COMPLETION_MARKER = "VG_SEM_DONE"
OBS_PREFIX = "VG_SEM_OBS"
PATH_PREFIX = "VG_SEM_PATH"
SAFE_ABS_MAX = 1_000_000
