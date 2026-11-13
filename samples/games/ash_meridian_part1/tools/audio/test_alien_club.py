import json
import unittest

import numpy as np

from alien_club import CHAMBERS, FRAMES, LOOP, OUTPUT, decode, measurements, render, schedule, voice, wrap_place
from dsp import SR


class AlienClubTests(unittest.TestCase):
	def test_sub_kicks_are_deep_punchy_and_irregular(self):
		kicks = [event for event in schedule() if event["kind"] == "sub_kick"]
		self.assertGreaterEqual(len(kicks), 40)
		onsets = np.array([event["time_seconds"] for event in kicks])
		gaps = np.diff(np.append(onsets, onsets[0] + LOOP))
		self.assertGreater(np.std(gaps) / np.mean(gaps), 0.5)
		self.assertLess(np.min(gaps), 0.9)
		self.assertGreater(np.max(gaps), 3.0)
		for event in kicks:
			self.assertEqual(event["pan"], 0.0)
			self.assertTrue(35 < event["frequency_hz"] < 65)
			clip = voice(event, np.random.default_rng(1))
			self.assertGreater(np.max(np.abs(clip[:SR // 20])), 0.5)
			tail = clip[SR // 5:SR // 2]
			spectrum = np.abs(np.fft.rfft(tail)) ** 2
			frequencies = np.fft.rfftfreq(len(tail), 1 / SR)
			self.assertGreater(np.sum(spectrum[(frequencies >= 25) & (frequencies <= 100)]) / np.sum(spectrum), 0.8)
			self.assertLess(np.sqrt(np.mean(clip[-SR // 10:] ** 2)), np.sqrt(np.mean(clip[:SR // 10] ** 2)) * 0.3)

	def test_rhythm_is_reproducible_asymmetric_and_fractional(self):
		events = schedule()
		self.assertEqual(events, schedule())
		self.assertEqual(len(set(CHAMBERS)), len(CHAMBERS))
		membranes = [event for event in events if event["kind"] == "membrane"]
		onsets = np.array([event["time_seconds"] for event in membranes])
		gaps = np.diff(np.append(onsets, onsets[0] + LOOP))
		self.assertGreater(np.std(gaps) / np.mean(gaps), 0.4)
		self.assertGreater(len(set(event["subdivision"].split("/")[1] for event in membranes)), 3)
		for event in events:
			self.assertTrue(0 <= event["time_seconds"] < LOOP)
			self.assertTrue(0 < event["duration_seconds"] < LOOP)
			self.assertTrue(-1 <= event["pan"] <= 1)
		self.assertTrue(any(event["time_seconds"] + event["duration_seconds"] > LOOP for event in events))

	def test_source_render_is_reproducible_and_continuous(self):
		audio, events = render()
		second, repeated_events = render()
		np.testing.assert_array_equal(audio, second)
		self.assertEqual(events, repeated_events)
		facts = measurements(audio)
		self.assertLessEqual(facts["peak"], 0.581)
		self.assertLess(max(facts["seam_step_per_channel"]), 0.025)
		self.assertGreater(facts["stereo_difference_rms"], 0.015)
		metadata = json.loads(OUTPUT.with_suffix(".json").read_text(encoding="utf-8"))
		self.assertAlmostEqual(facts["rms"], metadata["validation"]["source"]["rms"], places=5)

	def test_wrapped_tail_preserves_energy_and_position(self):
		audio = np.zeros((100, 2))
		clip = np.arange(20, dtype=float)
		wrap_place(audio, clip, 90 / SR)
		np.testing.assert_allclose(audio[90:, 0], clip[:10] / np.sqrt(2))
		np.testing.assert_allclose(audio[:10, 0], clip[10:] / np.sqrt(2))
		self.assertAlmostEqual(float(np.sum(audio ** 2)), float(np.sum(clip ** 2)))

	def test_delivered_ogg_and_metadata(self):
		metadata = json.loads(OUTPUT.with_suffix(".json").read_text(encoding="utf-8"))
		audio = decode(OUTPUT)
		facts = measurements(audio)
		self.assertEqual(audio.shape, (FRAMES, 2))
		self.assertGreaterEqual(facts["duration_seconds"], 90)
		self.assertLessEqual(facts["duration_seconds"], 120)
		self.assertLess(facts["peak"], 0.7)
		self.assertGreater(facts["rms"], 0.035)
		self.assertLess(facts["rms"], 0.18)
		self.assertLess(max(facts["seam_step_per_channel"]), 0.025)
		self.assertLess(max(abs(value) for value in facts["dc_per_channel"]), 0.001)
		self.assertGreater(facts["stereo_difference_rms"], 0.015)
		self.assertTrue(0.55 < facts["seam_head_rms"] / facts["seam_tail_rms"] < 1.8)
		self.assertEqual(metadata["events"], schedule())
		self.assertNotIn("bpm", metadata)
		self.assertEqual(metadata["loop_end_sample_exclusive"], FRAMES)
		np.testing.assert_allclose(facts["peak"], metadata["validation"]["decoded_vorbis"]["peak"])


if __name__ == "__main__":
	unittest.main()
