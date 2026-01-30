# Repository Cleanup Plan

## Documentation to Archive

Move to `docs/archive/` folder:
- ASYNC_JIT_REPL_STATUS.md (outdated status)
- COMPREHENSIVE_GAP_ANALYSIS.md (historical)
- COMPLETE_IMPLEMENTATION_SUMMARY.md (superseded)
- MODERNIZATION_SUMMARY.md (historical)
- MULTITASKING_IMPLEMENTATION_COMPLETE.md (historical)
- PERFORMANCE_TUNING_COMPLETE.md (superseded by OPTIMIZATION_RESULTS.md)
- PHASE_1_COMPLETION_CHECKLIST.md (historical)
- PRIORITY_IMPROVEMENTS.md (historical)
- PROJECT_STATUS_FINAL.md (historical)
- QUICK_START_PHASE_2.md (historical)
- INTEGRATION_TESTING_FINAL_REPORT.md (historical)
- TEST_RESULTS_FINAL.md (historical)
- DICT_PERFORMANCE_ANALYSIS.md (moved to TODO_FUTURE_OPTIMIZATIONS.md)

## Files to Delete

Temporary/Debug files:
- perf.data* (all perf data files)
- *.txt debug outputs (stack traces, reports)
- benchmark_results.txt
- run_benchmarks_*.txt
- bytecode_*.json
- dim-report.txt
- gdb_backtrace.txt
- offsets.txt
- sym_map.txt
- integration_test_*
- loop_*_trace.txt
- stack_trace_*.txt
- build.log, build_complete.log
- cons platform=linux target=template_release (typo file)

Downloaded archives:
- Godot_v4.5.1-stable_linux.x86_64 (3).zip
- godot-4.5.1-stable.tar.xz

Backup folders (after verification):
- _backups_advanced_features/
- _backups_debugging/
- _backups_multitasking/
- _backups_whenever_enhancements/
- _tmp_backup/

## Documentation to Keep (Main Level)

### User Documentation
- README.md (main entry point)
- GET_STARTED.md
- MIGRATION_GUIDE.md
- IMPORTING_VB6.md
- CONTRIBUTING.md
- LICENSE

### Reference Documentation
- BUILTIN_FUNCTIONS_REFERENCE.md
- GODOT_FUNCTIONS_REFERENCE.md
- GODOT_QUICK_REF.md
- MODERN_SYNTAX_QUICK_REF.md
- MODERN_FEATURES_README.md
- VB6_FEATURES_IMPLEMENTATION.md

### Status/Results
- IMPLEMENTATION_STATUS.md
- OPTIMIZATION_RESULTS.md
- PERFORMANCE_REPORT.md
- TEST_RESULTS.md
- TODO_FUTURE_OPTIMIZATIONS.md

### Development Guides
- DOCUMENTATION_INDEX.md
- FILE_INDEX.md
- REFACTORING_GUIDE.md
- README_DATA.md
- README_FORMS.md
- README_HELPERS.md

## Folder Structure Improvements

Create organized structure:
```
docs/
  ├── reference/          # API reference docs
  ├── guides/             # Tutorial/how-to guides
  ├── archive/            # Historical documentation
  └── development/        # Developer documentation

examples/                 # Example code
  ├── basic/
  ├── intermediate/
  └── advanced/

tests/                    # Test suite
  ├── unit/
  ├── integration/
  └── benchmarks/
```

## Next Steps

1. Create docs/archive/ directory
2. Move historical docs to archive
3. Delete temporary/debug files
4. Update DOCUMENTATION_INDEX.md
5. Update README.md with new structure
6. Clean git history (optional)
