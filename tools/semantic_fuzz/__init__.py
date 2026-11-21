"""VisualGasic semantic fuzz — Phase 1 typed IR, reference model, campaign."""

SCHEMA_VERSION = 1
GENERATOR_VERSION = 1
# v2: ParamSpec ByRef/ByVal, early-return stops subsequent stmts, call frames.
# v3: source_modules multi-file bundles; path_module_key; bound-run contracts.
# v4: fixed-size Integer arrays + present/missing Dictionary collection slice (C3).
# v5: DictMissCheck err_before + immediate Variant Err capture + err_type obs.
REFERENCE_VERSION = 5
COMPLETION_MARKER = "VG_SEM_DONE"
OBS_PREFIX = "VG_SEM_OBS"
PATH_PREFIX = "VG_SEM_PATH"
SAFE_ABS_MAX = 1_000_000
