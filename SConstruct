#!/usr/bin/env python
import os
import sys

env = SConscript("godot-cpp/SConstruct")

# Allow passing debug_build via command-line args to enable -g -O0
from SCons.Script import ARGUMENTS
if ARGUMENTS.get("debug_build", "0") == "1":
    env["debug_build"] = True

# Optional AddressSanitizer build flag: pass `asan=1` on scons command line
if ARGUMENTS.get("asan", "0") == "1":
    env.Append(CCFLAGS=["-fsanitize=address", "-fno-omit-frame-pointer", "-g", "-O1"])
    env.Append(LINKFLAGS=["-fsanitize=address"])

# For the reference:
# - godot-cpp/test/src and godot-cpp/test/header are the includes
# - src is our local source

env.Append(CPPPATH=["src"])
sources = Glob("src/*.cpp")

# Build variant flags: simple debug vs release heuristics driven by env['target']
if "debug" in env.get("target", "").lower() or env.get("debug_build", False):
    env.Append(CCFLAGS=["-g", "-O0"])
else:
    env.Append(CCFLAGS=["-O3", "-DNDEBUG"])

# Ensure debug symbols are preserved for template_debug builds (force link debug flags)
if "template_debug" in env.get("target", "").lower() or env.get("debug_build", False):
    env.Append(LINKFLAGS=["-g"])
    env.Append(LINKFLAGS=["-rdynamic"])  # ensure symbols exported for backtraces
    # Prevent automatic stripping of the produced shared library in debug builds.
    # Some toolchains or builders may run strip as a separate step; ensure STRIP is empty.
    env['STRIP'] = ''

# Force no automatic stripping for all builds in this repository to help debugging.
env['STRIP'] = ''

# Optional: allow using ccache by setting the environment variable USE_CCACHE=1
import os
if os.environ.get("USE_CCACHE", "0") == "1":
    # Prepend ccache to the compiler tool if available
    try:
        env.Prepend(CC="ccache "+env.get("CC", "gcc"))
    except Exception:
        pass

# Optional: treat warnings as errors via environment ARGUMENT (warn_as_error=1)
from SCons.Script import ARGUMENTS
if ARGUMENTS.get("warn_as_error", "0") == "1":
    env.Append(CCFLAGS=["-Wall", "-Werror"])


if env["platform"] == "macos":
    library = env.SharedLibrary(
        "demo/bin/libvisualgasic.{}.{}.framework/libvisualgasic.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
else:
    library = env.SharedLibrary(
        "demo/bin/visualgasic{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)

# Additional helper target: parser harness (link against same objects)
import os
if os.path.exists('tools/parser_harness.cpp'):
    try:
        prog = env.Program(target="tools/parser_harness", source=(['tools/parser_harness.cpp'] + sources))
        Default(prog)
    except Exception:
        pass

# Add a small parser repro binary to exercise parsing outside Godot (useful for ASAN runs)
if os.path.exists('tools/parser_repro.cpp'):
    try:
        prog_repro = env.Program(target="tools/parser_repro", source=(['tools/parser_repro.cpp'] + ['src/visual_gasic_tokenizer.cpp', 'src/visual_gasic_parser.cpp']))
        Default(prog_repro)
    except Exception:
        pass

# Only create parser unit programs if their source files exist to avoid build failures on trimmed checkouts
parser_unit_sources = ['tools/parser_unit_test.cpp', 'src/visual_gasic_tokenizer.cpp', 'src/visual_gasic_parser.cpp', 'src/init_probes.cpp', 'src/gde_stubs.cpp']
if all(os.path.exists(p) for p in parser_unit_sources):
    try:
        # Clone environment for parser_unit_test with special link flags to export symbols for dlsym
        env_parser_test = env.Clone()
        env_parser_test.Append(LINKFLAGS=['-rdynamic'])
        prog_unit = env_parser_test.Program(target="tools/parser_unit_test", source=parser_unit_sources)
        Default(prog_unit)
    except Exception:
        pass

prog_std_sources = ['tools/parser_unit_std.cpp', 'tools/standalone_tokenizer.cpp', 'tools/parser_std_parser.cpp']
if os.path.exists('tools/standalone_tokenizer.h') and all(os.path.exists(p) for p in prog_std_sources):
    try:
        prog_std = env.Program(target="tools/parser_unit_std", source=prog_std_sources)
        Default(prog_std)
    except Exception:
        pass

prog_std_test_sources = ['tools/parser_unit_std_test.cpp', 'tools/standalone_tokenizer.cpp', 'tools/parser_std_parser.cpp']
if os.path.exists('tools/standalone_tokenizer.h') and all(os.path.exists(p) for p in prog_std_test_sources):
    try:
        prog_std_test = env.Program(target="tools/parser_unit_std_test", source=prog_std_test_sources)
        Default(prog_std_test)
    except Exception:
        pass

if os.path.exists('tools/parser_unit_std_cli_test.cpp'):
    try:
        prog_std_cli_test = env.Program(target="tools/parser_unit_std_cli_test", source=['tools/parser_unit_std_cli_test.cpp'])
        Default(prog_std_cli_test)
    except Exception:
        pass

if os.path.exists('tools/parser_unit_std_golden_test.cpp'):
    try:
        prog_std_golden = env.Program(target="tools/parser_unit_std_golden_test", source=['tools/parser_unit_std_golden_test.cpp'])
        Default(prog_std_golden)
    except Exception:
        pass
