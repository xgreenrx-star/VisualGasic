#!/usr/bin/env python3
"""Build a lexical example inventory, not a semantic execution-coverage claim."""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
import subprocess
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

from audit_reference_dispatch import parse_godot_ref, parse_lang_ref
from build_command_reference import parse_help_db

ROOT = Path(__file__).resolve().parent.parent
REPORT = Path("docs/audit/example_coverage.md")
INVENTORY = Path("docs/audit/example_coverage.tsv")
VALIDATION = Path("docs/audit/example_coverage_validation.json")
NAMESPACES = {
    "camera", "sound", "speaker", "animation", "physics", "ray", "cell",
    "nav", "screen", "joypad", "touch", "sensor", "permission", "gps",
    "steps", "crypto", "theme", "js", "shader", "material", "skeleton",
    "bone", "video", "soundgen", "music", "tracker",
}
DISPATCH_FILES = {
    "visual_gasic_builtins.cpp", "visual_gasic_instance_builtins.cpp",
    "visual_gasic_instance_evaluate.inc", "visual_gasic_instance_execute.inc",
    "visual_gasic_instance_expr_compat.inc", "vg_godot_owner_builtins.cpp",
}
DISPATCH_PATTERN = re.compile(
    r'\b(?:METHOD_IS|M)\("([^"]+)"\)'
    r'|\b(?:method|p_method|name|func_name|func_name_lower|lowercase_name|method_name)'
    r'(?:\.nocasecmp_to\("([^"]+)"\)|\s*==\s*"([^"]+)")'
)
KEYWORD_PATTERN = re.compile(r'keywords\.push_back\("([^"]+)"\)')
PARSER_PATTERN = re.compile(r'\bval\s*==\s*"([^"]+)"')
IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z_0-9]*(?:[. ][A-Za-z_][A-Za-z_0-9]*)*$")
SYMBOLS = {"+", "-", "*", "/", "\\", "^", "**", "=", "<>", "<", ">", "<=", ">=", "&", "<<", ">>", "?.", "??", "%"}
PARSER_DEFINITIONS = {
    "parse_interface": "Interface", "parse_class": "Class", "parse_type": "Type",
    "parse_sub": "Sub", "parse_enum": "Enum", "parse_property": "Property",
    "parse_for": "For", "parse_select": "Select Case", "parse_while": "While",
    "parse_do": "Do", "parse_try": "Try", "parse_open": "Open",
    "parse_close": "Close", "parse_input": "Input", "parse_print": "Print",
    "parse_dim": "Dim", "parse_const": "Const", "parse_redim": "ReDim",
    "parse_seek": "Seek", "parse_kill": "Kill", "parse_name": "Name",
    "parse_data": "Data", "parse_read": "Read", "parse_restore": "Restore",
}


def key(name: str) -> str:
    return re.sub(r"\s+", " ", name.strip()).casefold()


def surface(name: str) -> str:
    prefix, separator, rest = name.partition("_")
    if separator and prefix.casefold() in NAMESPACES:
        return prefix + "." + rest
    return name


@dataclass
class Command:
    name: str
    kinds: set[str] = field(default_factory=set)
    aliases: set[str] = field(default_factory=set)
    docs: set[str] = field(default_factory=set)
    syntax: set[str] = field(default_factory=set)
    implementation: set[str] = field(default_factory=set)
    guards: set[str] = field(default_factory=set)


@dataclass
class Program:
    path: str
    category: str
    code: list[str]
    assertion_lines: int
    expected_output: bool
    verified: bool


def add(commands: dict[str, Command], name: str, kind: str) -> Command:
    canonical = surface(name)
    command = commands.setdefault(key(canonical), Command(canonical))
    command.kinds.add(kind)
    command.aliases.update((canonical, name))
    return command


def cpp_lines(text: str) -> list[str]:
    """Remove C++ comments while retaining dispatch string literals and lines."""
    pattern = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*.*?\*/', re.S)
    return pattern.sub(
        lambda match: re.sub(r"[^\n]", " ", match[0])
        if match[0].startswith(("//", "/*")) else match[0],
        text,
    ).splitlines()


def collect_commands(root: Path) -> dict[str, Command]:
    commands: dict[str, Command] = {}
    help_path = root / "addons/visual_gasic/vg_command_help.gd"
    help_text = help_path.read_text(encoding="utf-8")
    help_lines = {
        key(match[1]): help_text.count("\n", 0, match.start()) + 1
        for match in re.finditer(r'\b_add(?:_godot)?\(\s*"([^"]+)"', help_text)
    }
    for entry in parse_help_db(help_text):
        name = entry["keyword"]
        command = add(commands, name, "documented")
        command.docs.add(f"addons/visual_gasic/vg_command_help.gd:{help_lines[key(name)]}")
        command.syntax.add(entry["syntax"])
        if entry["godot_class"]:
            command.kinds.add("Godot API documentation")
    for parser, relative in [
        (parse_lang_ref, "docs/VisualGasic_Language_Reference.md"),
        (parse_godot_ref, "docs/reference/GODOT_FUNCTIONS_REFERENCE.md"),
    ]:
        for entry in parser(root / relative):
            command = add(commands, entry.name, "documented")
            command.docs.add(f"{relative}:{entry.line}")

    for path in sorted((root / "src").rglob("*")):
        if path.suffix not in {".cpp", ".inc", ".h"} or not path.is_file():
            continue
        relative = path.relative_to(root).as_posix()
        lines = cpp_lines(path.read_text(encoding="utf-8"))
        for number, line in enumerate(lines, 1):
            matches: list[tuple[str, str]] = []
            if path.name in DISPATCH_FILES:
                for match in DISPATCH_PATTERN.finditer(line):
                    matches.append((next(group for group in match.groups() if group), "dispatch literal"))
            if path.name == "visual_gasic_tokenizer.cpp":
                matches.extend((match[1], "token") for match in KEYWORD_PATTERN.finditer(line))
            if path.name == "visual_gasic_parser.cpp":
                matches.extend((match[1], "parser branch") for match in PARSER_PATTERN.finditer(line))
                definition = re.search(r"VisualGasicParser::(parse_[a-z_]+)\(", line)
                if definition and definition[1] in PARSER_DEFINITIONS:
                    matches.append((PARSER_DEFINITIONS[definition[1]], "parser definition"))
                if re.search(r"\bForEachStatement\s*\*", line):
                    matches.append(("For Each", "parser node construction"))
                if re.search(r"\bOnErrorStatement\s*\*", line):
                    matches.append(("On Error", "parser node construction"))
            if path.name == "visual_gasic_godot_ctors.h" and re.match(r'^\s*"[a-z0-9]+",', line):
                matches.append((re.search(r'"([^"]+)"', line)[1], "value constructor"))
            for name, kind in matches:
                if not IDENTIFIER.fullmatch(name):
                    continue
                command = add(commands, name, kind)
                command.implementation.add(f"{relative}:{number}")
                if "size()" in line:
                    command.guards.add(f"{relative}:{number}: {line.strip()}")
    builtin_reference = root / "docs/reference/BUILTIN_FUNCTIONS_REFERENCE.md"
    if builtin_reference.is_file():
        for number, line in enumerate(vg_code(builtin_reference.read_text(encoding="utf-8")), 1):
            for match in re.finditer(r"\b([A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)*)\s*\(", line):
                name = surface(match[1])
                if key(name) in commands:
                    command = commands[key(name)]
                    command.kinds.add("documented")
                    command.docs.add(f"docs/reference/BUILTIN_FUNCTIONS_REFERENCE.md:{number}")
    return commands


def vg_code(text: str) -> list[str]:
    """Strip VB comments, strings and date literals without matching their text."""
    result: list[str] = []
    for line in text.splitlines():
        code: list[str] = []
        i = 0
        while i < len(line):
            character = line[i]
            if character == "'":
                break
            if character == '"':
                code.append(" ")
                i += 1
                while i < len(line):
                    if line[i] == '"':
                        i += 1
                        if i < len(line) and line[i] == '"':
                            i += 1
                            continue
                        break
                    i += 1
                continue
            if character == "#":
                end = line.find("#", i + 1)
                if end >= 0 and ("/" in line[i + 1:end] or ":" in line[i + 1:end]):
                    code.append(" ")
                    i = end + 1
                    continue
            code.append(character)
            i += 1
        cleaned = "".join(code)
        cleaned = re.sub(r"(^|:)\s*Rem(?:\s.*|$)", r"\1", cleaned, flags=re.I)
        result.append(cleaned)
    return result


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def runtime_hashes(root: Path) -> dict[str, str]:
    paths = [path for path in (root / "src").rglob("*")
             if path.is_file() and path.suffix in {".cpp", ".h", ".inc"}]
    paths += [root / relative for relative in [
        "test_proj/run_corpus.gd", "test_proj/run_suite.gd",
        "test_proj/run_await_resource_lifetime.gd",
        "scripts/audit_corpus.sh", "scripts/run_ast_bytecode_diff.sh",
        "addons/visual_gasic/visual_gasic.gdextension",
        "addons/visual_gasic/bin/libvisualgasic.linux.editor.x86_64.so",
        "addons/visual_gasic/bin/libvisualgasic.linux.template_debug.x86_64.so",
    ] if (root / relative).is_file()]
    return {path.relative_to(root).as_posix(): digest(path) for path in sorted(paths)}


def capture_validation(root: Path, corpus_logs: list[Path], differential_log: Path) -> dict:
    if len({log.resolve() for log in corpus_logs}) != len(corpus_logs):
        raise ValueError("Corpus evidence logs must be distinct")
    corpus = sorted((root / "corpus").rglob("*.vg"))
    paths = {path.relative_to(root).as_posix(): path for path in corpus}
    runs = []
    for log in corpus_logs:
        text = log.read_text(encoding="utf-8")
        passed = re.findall(r"^PASS: (corpus/[^\n]+\.vg)$", text, re.M)
        summary = f"=== CORPUS AUDIT: {len(corpus)} pass, 0 fail, 0 skipped ==="
        if set(passed) != set(paths) or len(passed) != len(paths) or summary not in text:
            raise ValueError(f"Incomplete or failing corpus evidence: {log}")
        runs.append({"log": log.name, "sha256": digest(log)})
    text = differential_log.read_text(encoding="utf-8")
    if re.search(r"^\s*(?:DIFF|EXEC-FAIL|BOTH-FAIL|NO-ASSERT)\s", text, re.M):
        raise ValueError(f"Failing differential evidence: {differential_log}")
    if "All compared tests agree across bytecode and AST paths." not in text:
        raise ValueError(f"Incomplete differential evidence: {differential_log}")
    fixtures = re.findall(r"^\s*OK\s+(test_\S+\.vg)\s+\(bc=(\d+)\s+ast=(\d+)\)", text, re.M)
    if not fixtures or any(int(bc) < 1 or int(ast) < 1 for _, bc, ast in fixtures):
        raise ValueError("Differential evidence has no assertion-bearing passing fixtures")
    matched = re.search(r"Matched OK:\s+(\d+)", text)
    if not matched or int(matched[1]) != len(fixtures):
        raise ValueError("Differential passing fixture count does not match summary")
    verified = {name: digest(path) for name, path in paths.items()}
    for name, _, _ in fixtures:
        path = root / "test_proj/test_suite" / name
        if not path.is_file():
            raise ValueError(f"Missing validated fixture: {path}")
        verified[path.relative_to(root).as_posix()] = digest(path)
    return {
        "schema": 1,
        "scope": "Linux; corpus default/forced AST on Godot 4.7.2 and 4.6.1; differential on 4.7.2",
        "corpus_runs": runs,
        "differential": {"log": differential_log.name, "sha256": digest(differential_log),
                         "matched": len(fixtures)},
        "files": verified,
        "runtime": runtime_hashes(root),
        "hash_note": "Hashes captured from the working tree during inventory generation, not embedded by the test runner.",
    }


def collect_programs(root: Path, validation: dict) -> tuple[list[Program], list[str]]:
    runtime_unchanged = bool(validation) and validation.get("runtime") == runtime_hashes(root)
    tracked = subprocess.run(
        ["git", "ls-files", "-z", "--", "corpus", "samples", "test_proj"],
        cwd=root, check=True, capture_output=True,
    ).stdout.decode("utf-8").split("\0")
    paths = sorted(name for name in tracked if name.endswith(".vg"))
    programs: list[Program] = []
    unavailable: list[str] = []
    for name in paths:
        if "/addons/" in name:
            continue
        path = root / name
        if not path.is_file():
            unavailable.append(name)
            continue
        if name.startswith("corpus/"):
            category = "corpus"
        elif name.startswith("samples/"):
            category = "sample"
        elif name.startswith("test_proj/test_suite/"):
            category = "regression"
        else:
            category = "other fixture"
        text = path.read_text(encoding="utf-8")
        code = vg_code(text)
        assertions = sum(
            bool(re.search(r'\bAssert\b', clean, re.I) or
                 (re.search(r"\bPrint\b", clean, re.I) and
                  re.search(r'"(?:PASS|FAIL):', original)))
            for original, clean in zip(text.splitlines(), code)
        )
        programs.append(Program(
            name, category, code, assertions, "' Expected output:" in text,
            runtime_unchanged and validation.get("files", {}).get(name) == digest(path),
        ))
    return programs, unavailable


def match_names(command: Command) -> set[str]:
    names = set(command.aliases)
    # Captions such as "SCREEN (QuickBASIC)" are not literal VG syntax.
    names.update(re.sub(r"\s+\([^)]*\)$", "", name) for name in command.aliases)
    return names


def matcher(command: Command) -> re.Pattern:
    patterns = []
    for name in sorted(match_names(command)):
        if name in SYMBOLS:
            characters = re.escape("+-*/\\^=<> &?.%".replace(" ", ""))
            patterns.append(r"(?<![" + characters + "])" + re.escape(name) + r"(?![" + characters + "])")
            continue
        if not IDENTIFIER.fullmatch(name):
            continue
        parts = re.split(r"([. ])", name)
        patterns.append(r"(?<![\w])" + "".join(
            r"\s*\.\s*" if part == "." else r"\s+" if part == " " else re.escape(part)
            for part in parts
        ) + r"(?![\w])")
    return re.compile("(?:" + ("|".join(patterns) or r"(?!)") + ")", re.I)


def collect_rows(commands: dict[str, Command], programs: list[Program]) -> list[dict]:
    token_index: dict[str, set[int]] = {}
    for index, program in enumerate(programs):
        for token in set(re.findall(r"[A-Za-z_][A-Za-z_0-9]*", "\n".join(program.code).casefold())):
            token_index.setdefault(token, set()).add(index)
    rows = []
    for command in sorted(commands.values(), key=lambda item: key(item.name)):
        pattern = matcher(command)
        references: dict[str, list[str]] = {
            "corpus": [], "sample": [], "regression": [], "other fixture": [],
            "verified corpus": [], "verified regression": [], "assertion fixture": [],
        }
        candidates: set[int] = set()
        for name in match_names(command):
            if name in SYMBOLS:
                candidates.update(range(len(programs)))
            elif IDENTIFIER.fullmatch(name):
                candidates.update(token_index.get(re.split(r"[. ]", name)[0].casefold(), set()))
        for index in sorted(candidates):
            program = programs[index]
            hits = [number for number, line in enumerate(program.code, 1) if pattern.search(line)]
            if not hits:
                continue
            location = f"{program.path}:{hits[0]}"
            references[program.category].append(location)
            if program.verified and program.category in {"corpus", "regression"}:
                references["verified " + program.category].append(location)
            if program.assertion_lines and program.category == "regression":
                references["assertion fixture"].append(location)
        rows.append({
            "command": command.name, "kinds": sorted(command.kinds),
            "implementation": sorted(command.implementation), "documentation": sorted(command.docs),
            "syntax": sorted(command.syntax), "argument_guard_evidence": sorted(command.guards),
            "references": references,
            "teaching_gap": not references["corpus"],
            "regression_gap": not references["assertion fixture"],
            "reference_status": (
                "corpus and assertion-fixture references" if references["corpus"] and references["assertion fixture"]
                else "corpus reference only" if references["corpus"]
                else "assertion-fixture reference; no corpus" if references["assertion fixture"]
                else "sample/other reference only" if references["sample"] or references["other fixture"] or references["regression"]
                else "no active VG reference"
            ),
            "overload_coverage": "unverified", "error_path_coverage": "unverified",
        })
    return rows


def render_tsv(rows: list[dict]) -> str:
    output = io.StringIO(newline="")
    fields = [
        "command", "kinds", "implementation", "documentation", "syntax",
        "argument_guard_evidence", "reference_status", "teaching_gap", "regression_gap",
        "overload_coverage", "error_path_coverage",
    ]
    groups = list(rows[0]["references"]) if rows else []
    fields += groups
    writer = csv.DictWriter(output, fieldnames=fields, delimiter="\t", lineterminator="\n")
    writer.writeheader()
    for row in rows:
        values = {name: row[name] for name in fields if name not in groups}
        values.update(row["references"])
        writer.writerow({
            name: json.dumps(value, ensure_ascii=True) if isinstance(value, list) else value
            for name, value in values.items()
        })
    return output.getvalue()


def render_report(rows: list[dict], programs: list[Program], unavailable: list[str], validation: dict) -> str:
    documented = [row for row in rows if "documented" in row["kinds"]]
    dispatch = [row for row in rows if "dispatch literal" in row["kinds"]]
    counts = Counter(program.category for program in programs)
    missing = [row for row in documented if row["teaching_gap"]]
    both = [row for row in documented if row["teaching_gap"] and row["regression_gap"]]
    absent = [row for row in documented if row["reference_status"] == "no active VG reference"]
    summary = [
        ("Inventory entries (case-insensitive; aliases may remain separate)", len(rows)),
        ("Documented entries", len(documented)),
        ("Entries with runtime dispatch-literal evidence", len(dispatch)),
        ("Documented entries with a corpus code reference", len(documented) - len(missing)),
        ("Documented entries without a corpus code reference", len(missing)),
        ("Documented entries without an assertion-bearing regression reference",
         sum(row["regression_gap"] for row in documented)),
        ("Documented entries missing both kinds of reference", len(both)),
        ("Documented entries with no active VG code reference anywhere scanned", len(absent)),
        ("Entries without extracted implementation evidence (needs review)",
         sum(not row["implementation"] for row in rows)),
        ("Available corpus / sample / regression / other VG files",
         f'{counts["corpus"]} / {counts["sample"]} / {counts["regression"]} / {counts["other fixture"]}'),
        ("Unavailable tracked VG files (not silently counted as covered)", len(unavailable)),
        ("Current hash-matched verified corpus / regression fixtures",
         f'{sum(program.verified and program.category == "corpus" for program in programs)} / '
         f'{sum(program.verified and program.category == "regression" for program in programs)}'),
    ]
    lines = [
        "# Command and example coverage inventory", "",
        "Generated by [audit_example_coverage.py](../../scripts/audit_example_coverage.py).",
        "The complete per-entry mapping is [example_coverage.tsv](example_coverage.tsv).",
        "Validation provenance and file hashes are in",
        "[example_coverage_validation.json](example_coverage_validation.json).", "",
        "## What these numbers mean", "",
        "**No: the examples do not cover all commands.** This is a reproducible",
        "lexical inventory, not semantic code coverage or a certification of support.",
        "A reference means the spelling occurs in VG code, outside comments, strings",
        "and date literals. It may be a declaration, a shadowed name, a property or",
        "an unreachable branch. It does not prove the intended command ran.",
        "Assertion-bearing means the fixture contains assertions, not that each",
        "matched command has its own assertion.", "",
        "| Metric | Count |", "|---|---:|",
    ]
    lines += [f"| {label} | {count} |" for label, count in summary]
    lines += [
        "", "## Scope and limitations", "",
        "- Union of command-help entries, command sections in the language/Godot",
        "  references, runtime dispatch literals in the central builtin/evaluator",
        "  files, tokenizer keywords, direct parser branches and value constructors.",
        "  Known inventory call names in builtin-reference snippets also add",
        "  documentation evidence; arbitrary prose names do not create commands.",
        "- Tokens include modifiers, types and block delimiters, not just commands.",
        "  Source-only dispatch entries may be aliases or receiver-specific methods.",
        "- Extracted implementation evidence is a source location, **not** proof",
        "  of support in both AST and bytecode. No evidence means review needed,",
        "  not necessarily unsupported. Token-only entries are not treated as",
        "  implemented commands.",
        "- Namespace handler names such as `camera_shake` also match `Camera.Shake`.",
        "  Other spellings remain separate; no inferred alias establishes coverage.",
        "- Arbitrary inherited Godot/ClassDB methods, dynamic calls, external plugin",
        "  APIs and editor menu commands are outside this finite inventory.",
        "  Instance-method receiver types are not resolved.",
        "- Only tracked VG files in active corpus, samples and test_proj are scanned.",
        "  Vendored `/addons/` copies inside projects are excluded, not counted",
        "  repeatedly as teaching programs.",
        "  Ignored scratch archives, documentation snippets and GDScript harness code",
        "  do not count as runnable VG examples. Includes/imports are not expanded.",
        "- Full source locations, documented syntaxes and same-line argument guards",
        "  are retained in the TSV. Overload and error-path coverage is explicitly",
        "  **unverified for every entry**; lexical matching cannot establish either.",
        "", "## Verified fixtures, not verified commands", "",
    ]
    if validation:
        lines += [
            f'The recorded corpus evidence has {len(validation["corpus_runs"])} passing runs;',
            f'the recorded differential evidence has {validation["differential"]["matched"]}',
            "matched passing fixtures. A verified-reference column is populated only",
            "when the current VG file, native-source, binary and runner hashes match",
            "that captured evidence.",
            "The capture records successful logs supplied by the maintainer; it",
            "does not rerun Godot or infer the engine/mode from output banners.",
            "Hashes are captured at inventory generation, not embedded by the test",
            "runner; the supplied logs must correspond to that working-tree content.",
            "Changing a fixture invalidates its verified-reference status.",
        ]
    else:
        lines.append("No runtime validation snapshot supplied; all references are unverified.")
    lines += [
        "", "## How to use the inventory", "",
        "Each TSV row has corpus, sample, regression and other-fixture locations.",
        "Arrays of locations are JSON-encoded so punctuation is unambiguous.",
        "`teaching_gap=True` means no active corpus code reference;",
        "`regression_gap=True` means no assertion-bearing regression reference.",
        "A sample reference is not automatically a passing sample.",
        "For example, a `Using` spelling in `Palette Using` does not establish",
        "support for a resource-management `Using ... End Using` block.",
        "", "Start with documented entries that lack both teaching and regression",
        "references. Confirm implementation first, then add small runnable lessons",
        "with deterministic output and tests for supported overloads and failures.",
        "The initial six teaching batches are now represented by 22 added corpus",
        "lessons. References still do not prove coverage of all overloads or errors.",
        "", "### Added teaching batches", "",
        "1. Enums and user-defined types; optional parameters and ParamArray.",
        "2. ReDim/Erase, legacy On Error/Resume and binary/random-access files.",
        "3. Lambdas, functional helpers, Await, interfaces and optional chaining.",
        "4. JSON, regex, StringBuilder, dates and financial functions.",
        "5. Drawing, physics, audio, scenes and Tween with explicit host fixtures.",
        "6. Networking and Python interop with local, bounded dependencies.",
        "",
        "For each batch, verify documented syntax against implementation, then",
        "pair a corpus lesson with focused positive, invalid-input and overload",
        "tests. Do not turn deprecated names or documentation-only features into",
        "purportedly supported examples.",
        "", "### Documented entries with no active VG reference", "",
    ]
    lines += ["- `" + row["command"].replace("`", "") + "`" for row in absent]
    lines += [
        "", "### Documented entries missing corpus and assertion-fixture references", "",
        "This second list can include commands referenced by sample projects.",
        "",
    ]
    lines += ["- `" + row["command"].replace("`", "") + "`" for row in both]
    lines += [
        "", "## Reproducing", "", "```bash",
        "python3 scripts/audit_example_coverage.py --write",
        "python3 scripts/audit_example_coverage.py --check",
        "python3 scripts/audit_example_coverage.py --command Await",
        "python3 -m unittest discover -s scripts -p 'test_example_coverage.py'",
        "```", "",
        "The inventory is deterministic for the active tracked files and validation",
        "snapshot. Quarantining/restoring files changes it; `--check` detects stale",
        "generated outputs. It is a freshness check, not a language release gate.",
        "", "To capture new runtime evidence after executing the audits:", "", "```bash",
        "python3 scripts/audit_example_coverage.py --write \\",
        "  --corpus-log /path/to/472-default.log --corpus-log /path/to/472-ast.log \\",
        "  --corpus-log /path/to/461-default.log --corpus-log /path/to/461-ast.log \\",
        "  --differential-log /path/to/full-differential.log",
        "```", "",
        "All four corpus logs must contain every current corpus file and zero",
        "failures/skips. The differential log must finish successfully.",
        "",
        "## Unavailable tracked VG files", "",
        "These paths remain tracked but are absent in this local working tree.",
        "They are not removed by this audit and their ignored archives are not scanned.", "",
    ]
    lines += ["- `" + name + "`" for name in unavailable]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--write", action="store_true")
    action.add_argument("--check", action="store_true")
    parser.add_argument("--command", help="Print the full JSON row for an entry")
    parser.add_argument("--corpus-log", type=Path, action="append", default=[])
    parser.add_argument("--differential-log", type=Path)
    args = parser.parse_args()
    if args.corpus_log or args.differential_log:
        if not args.write or len(args.corpus_log) != 4 or not args.differential_log:
            parser.error("Evidence capture requires --write, four --corpus-log arguments and --differential-log")
        validation = capture_validation(ROOT, args.corpus_log, args.differential_log)
    else:
        validation = json.loads((ROOT / VALIDATION).read_text(encoding="utf-8")) if (ROOT / VALIDATION).exists() else {}
    programs, unavailable = collect_programs(ROOT, validation)
    rows = collect_rows(collect_commands(ROOT), programs)
    if args.command:
        selected = [row for row in rows if key(row["command"]) == key(surface(args.command))]
        if not selected:
            parser.error(f"No inventory entry: {args.command}")
        print(json.dumps(selected[0], indent=2))
        return 0
    outputs = {
        REPORT: render_report(rows, programs, unavailable, validation),
        INVENTORY: render_tsv(rows),
    }
    if args.corpus_log:
        outputs[VALIDATION] = json.dumps(validation, indent=2, sort_keys=True) + "\n"
    if args.write:
        for path, text in outputs.items():
            (ROOT / path).write_text(text, encoding="utf-8")
    elif args.check:
        stale = [str(path) for path, text in outputs.items()
                 if not (ROOT / path).is_file() or (ROOT / path).read_text(encoding="utf-8") != text]
        if stale:
            print("Stale coverage outputs: " + ", ".join(stale))
            return 1
    print(f"Inventory: {len(rows)} entries, {len(programs)} available VG files, {len(unavailable)} unavailable.")
    print(f"Teaching gaps: {sum(row['teaching_gap'] for row in rows)}; "
          f"regression-reference gaps: {sum(row['regression_gap'] for row in rows)}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
