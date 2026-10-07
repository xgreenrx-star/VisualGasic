from __future__ import annotations

import csv
import io
import tempfile
import unittest
from pathlib import Path
from subprocess import CompletedProcess
from unittest.mock import patch

from audit_example_coverage import (
    Command, Program, capture_validation, collect_commands, collect_programs,
    collect_rows, cpp_lines, digest, key, matcher, render_report, render_tsv, runtime_hashes,
    surface, vg_code,
)


class ExampleCoverageTests(unittest.TestCase):
    def test_restored_inventory_has_no_trailing_blank_line(self):
        rows = collect_rows({"absent": Command("Absent", aliases={"Absent"})}, [])
        report = render_report(rows, [], [], {})
        self.assertIn("None. All tracked VG source files are available.", report)
        self.assertTrue(report.endswith("\n"))
        self.assertFalse(report.endswith("\n\n"))

    def test_comments_strings_and_dates_do_not_count(self):
        source = '''' Await Foo
Rem Tween thing
Print "Await ""Lambda"" Interface" ' Enum
Dim day = #1/15/2026#
Open "user://data.txt" For Input As #1
Close #1
Await 0
'''
        code = vg_code(source)
        self.assertFalse(any("Lambda" in line or "Interface" in line for line in code))
        self.assertEqual(sum(bool(matcher(Command("Await", aliases={"Await"})).search(line)) for line in code), 1)
        self.assertIn("#1", code[4])
        self.assertNotIn("2026", code[3])

    def test_token_boundaries_and_compound_commands(self):
        pattern = matcher(Command("For Each", aliases={"For Each"}))
        self.assertTrue(pattern.search("For   Each item In things"))
        self.assertFalse(pattern.search("ForEach item"))
        self.assertFalse(matcher(Command("Sin", aliases={"Sin"})).search("Single"))

    def test_namespace_alias_is_explicit(self):
        self.assertEqual(surface("camera_shake"), "camera.shake")
        self.assertEqual(surface("get_node"), "get_node")
        pattern = matcher(Command("Camera.Shake", aliases={"camera_shake", "Camera.Shake"}))
        self.assertTrue(pattern.search("Camera . Shake(2)"))
        self.assertTrue(pattern.search("camera_shake(2)"))
        self.assertFalse(pattern.search("OtherCamera.Shake(2)"))

    def test_cpp_comments_are_not_dispatch_evidence(self):
        source = '// METHOD_IS("fake")\nMETHOD_IS("real") /*\nMETHOD_IS("fake")\n*/\n'
        lines = cpp_lines(source)
        self.assertEqual(len(lines), 4)
        self.assertNotIn("fake", "".join(lines))
        self.assertIn('"real"', lines[1])

    def test_caption_matches_code_but_not_substring(self):
        pattern = matcher(Command("SCREEN (QuickBASIC)", aliases={"SCREEN (QuickBASIC)"}))
        self.assertTrue(pattern.search("SCREEN 13"))
        self.assertFalse(pattern.search("ScreenMode 13"))

    def test_operator_captions_match_only_the_exact_operator(self):
        pattern = matcher(Command("<< (Shift Left)", aliases={"<< (Shift Left)"}))
        self.assertTrue(pattern.search("value = 1 << 3"))
        self.assertFalse(pattern.search("value <= 3"))
        less = matcher(Command("<", aliases={"<"}))
        self.assertFalse(less.search("value <= 3"))
        self.assertTrue(less.search("value < 3"))

    def test_fixture_verification_is_not_overload_coverage(self):
        command = Command("Await", aliases={"Await"})
        programs = [
            Program("corpus/a.vg", "corpus", ["Await 0"], 0, True, True),
            Program("samples/b.vg", "sample", ["' not scanned", "Await 1"], 0, False, False),
            Program("test_proj/test_suite/test_a.vg", "regression", ["Await 0"], 1, False, True),
        ]
        row = collect_rows({key("Await"): command}, programs)[0]
        self.assertFalse(row["teaching_gap"])
        self.assertFalse(row["regression_gap"])
        self.assertEqual(row["overload_coverage"], "unverified")
        self.assertEqual(row["error_path_coverage"], "unverified")
        self.assertEqual(row["references"]["verified regression"], ["test_proj/test_suite/test_a.vg:1"])
        parsed = list(csv.DictReader(io.StringIO(render_tsv([row])), delimiter="\t"))
        self.assertEqual(parsed[0]["command"], "Await")

    def test_nonasserting_fixture_does_not_close_regression_gap(self):
        command = Command("Tween", aliases={"Tween"})
        program = Program("test_proj/test_suite/test_a.vg", "regression", ["Tween x"], 0, False, False)
        row = collect_rows({"tween": command}, [program])[0]
        self.assertTrue(row["regression_gap"])
        self.assertTrue(row["teaching_gap"])
        self.assertEqual(row["reference_status"], "sample/other reference only")

    def test_missing_reference_status_is_explicit(self):
        command = Command("Absent", aliases={"Absent"})
        row = collect_rows({"absent": command}, [])[0]
        self.assertEqual(row["reference_status"], "no active VG reference")
        self.assertTrue(row["teaching_gap"])
        self.assertTrue(row["regression_gap"])

    def test_assertion_fixture_without_corpus_is_not_a_teaching_example(self):
        command = Command("Interface", aliases={"Interface"})
        program = Program("test_proj/test_suite/test_interface.vg", "regression", ["Interface I"], 1, False, True)
        row = collect_rows({"interface": command}, [program])[0]
        self.assertEqual(row["reference_status"], "assertion-fixture reference; no corpus")
        self.assertTrue(row["teaching_gap"])
        self.assertFalse(row["regression_gap"])

    def test_inventory_extracts_source_and_documentation_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder in ["src", "addons/visual_gasic", "docs/reference"]:
                (root / folder).mkdir(parents=True)
            (root / "addons/visual_gasic/vg_command_help.gd").write_text(
                '_add("Await", "Await seconds", "Suspend.", "Await 0")\n',
                encoding="utf-8",
            )
            (root / "docs/VisualGasic_Language_Reference.md").write_text(
                "## Await\n**Syntax**\n\n    Await seconds\n", encoding="utf-8",
            )
            (root / "docs/reference/GODOT_FUNCTIONS_REFERENCE.md").write_text("", encoding="utf-8")
            (root / "src/visual_gasic_builtins.cpp").write_text(
                '// METHOD_IS("fake")\nif (METHOD_IS("camera_shake") && args.size() >= 2) {}\n',
                encoding="utf-8",
            )
            (root / "src/visual_gasic_parser.cpp").write_text(
                "InterfaceDefinition* VisualGasicParser::parse_interface() {}\n",
                encoding="utf-8",
            )
            commands = collect_commands(root)
            self.assertNotIn("fake", commands)
            self.assertIn("Await seconds", commands["await"].syntax)
            self.assertIn("parser definition", commands["interface"].kinds)
            self.assertEqual(commands["camera.shake"].implementation, {"src/visual_gasic_builtins.cpp:2"})
            self.assertEqual(len(commands["camera.shake"].guards), 1)

    def test_scan_excludes_addons_and_invalidates_changed_runtime(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "src").mkdir()
            source = root / "src/runtime.cpp"
            source.write_text("original", encoding="utf-8")
            (root / "corpus").mkdir()
            lesson = root / "corpus/a.vg"
            lesson.write_text('Print "PASS: not a regression"\n', encoding="utf-8")
            tracked = b"corpus/a.vg\0samples/addons/internal.vg\0samples/missing.vg\0"
            validation = {"runtime": runtime_hashes(root), "files": {"corpus/a.vg": digest(lesson)}}
            with patch("audit_example_coverage.subprocess.run", return_value=CompletedProcess([], 0, tracked)):
                programs, unavailable = collect_programs(root, validation)
                self.assertEqual(len(programs), 1)
                self.assertTrue(programs[0].verified)
                self.assertEqual(unavailable, ["samples/missing.vg"])
                source.write_text("modified", encoding="utf-8")
                programs, _ = collect_programs(root, validation)
                self.assertFalse(programs[0].verified)

    def test_validation_capture_rejects_missing_and_failed_runs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            corpus = root / "corpus"
            suite = root / "test_proj/test_suite"
            corpus.mkdir()
            suite.mkdir(parents=True)
            lesson = corpus / "a.vg"
            lesson.write_text("Print 1\n", encoding="utf-8")
            fixture = suite / "test_a.vg"
            fixture.write_text('Print "PASS: check"\n', encoding="utf-8")
            corpus_log = root / "corpus.log"
            diff_log = root / "diff.log"
            corpus_log.write_text("PASS: corpus/a.vg\n=== CORPUS AUDIT: 1 pass, 0 fail, 0 skipped ===\n", encoding="utf-8")
            diff_log.write_text("OK test_a.vg (bc=1 ast=1)\nMatched OK: 1\nAll compared tests agree across bytecode and AST paths.\n", encoding="utf-8")
            snapshot = capture_validation(root, [corpus_log], diff_log)
            self.assertEqual(snapshot["files"]["corpus/a.vg"], digest(lesson))
            old_hash = snapshot["files"]["corpus/a.vg"]
            lesson.write_text("Print 2\n", encoding="utf-8")
            self.assertNotEqual(old_hash, digest(lesson))
            diff_log.write_text("EXEC-FAIL test_a.vg\nAll compared tests agree across bytecode and AST paths.\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                capture_validation(root, [corpus_log], diff_log)
            with self.assertRaises(ValueError):
                capture_validation(root, [corpus_log, corpus_log], diff_log)
            corpus_log.write_text("=== CORPUS AUDIT: 1 pass, 0 fail, 0 skipped ===\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                capture_validation(root, [corpus_log], diff_log)


if __name__ == "__main__":
    unittest.main()
