import json
import unittest

import numpy as np

from alien_club import OUTPUT, decode, measurements
from alien_club_set import TRACKS, WORDS, schedule_track, sung_syllable


class AlienClubSetTests(unittest.TestCase):
	def test_distinct_arrangements_and_original_vocals(self):
		for kind, _, _ in TRACKS:
			events = schedule_track(kind)
			self.assertEqual(events, schedule_track(kind))
			vocals = [event for event in events if event["kind"] == "vocal"]
			self.assertGreaterEqual(len(vocals), 30)
			self.assertEqual(set(event["word"] for event in vocals), set(WORDS))
			clip = sung_syllable(vocals[0], np.random.default_rng(1))
			self.assertTrue(np.all(np.isfinite(clip)))
			self.assertGreater(np.sqrt(np.mean(clip ** 2)), 0.1)
			kicks = [event for event in events if event["kind"] == "sub_kick"]
			if kind == "lullaby":
				self.assertEqual(len(kicks), 0)
				self.assertGreater(min(event["duration_seconds"] for event in vocals), 1.6)
			else:
				self.assertGreaterEqual(len(kicks), 60)
				onsets = np.array([event["time_seconds"] for event in kicks])
				self.assertGreater(np.std(np.diff(onsets)) / np.mean(np.diff(onsets)), 0.4)
				self.assertLess(max(event["duration_seconds"] for event in vocals), 0.4)

	def test_delivered_tracks_and_metadata(self):
		for kind, title, _ in TRACKS:
			path = OUTPUT.with_name(f"club_{kind}.ogg")
			metadata = json.loads(path.with_suffix(".json").read_text(encoding="utf-8"))
			facts = measurements(decode(path))
			self.assertEqual(metadata["title"], title)
			self.assertEqual(metadata["events"], schedule_track(kind))
			self.assertEqual(metadata["external_audio_sources"], [])
			self.assertLess(facts["peak"], 0.7)
			self.assertGreater(facts["rms"], 0.035)
			self.assertLess(facts["rms"], 0.18)
			self.assertLess(max(facts["seam_step_per_channel"]), 0.025)
			self.assertNotIn("bpm", metadata)
			self.assertAlmostEqual(facts["peak"], metadata["validation"]["peak"], places=5)


if __name__ == "__main__":
	unittest.main()
