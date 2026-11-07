import unittest

import numpy as np

from dsp import SR
from sfx2 import buggy_motor
from sfx3 import buggy_coast, buggy_idle


class VehicleAudioTests(unittest.TestCase):
	def test_motor_loops_have_no_clicks_or_abrupt_seams(self):
		for generate in (buggy_motor, buggy_idle, buggy_coast):
			with self.subTest(loop=generate.__name__):
				audio = generate()
				steps = np.diff(np.concatenate((audio, audio[:1])))
				self.assertTrue(np.all(np.isfinite(audio)))
				self.assertLessEqual(np.max(np.abs(audio)), 0.61)
				self.assertLess(np.max(np.abs(steps)), 0.03)
				self.assertLessEqual(abs(steps[-1]), np.max(np.abs(steps[:-1])) * 1.01)

	def test_motor_loops_have_no_high_frequency_crackle(self):
		for generate in (buggy_motor, buggy_idle, buggy_coast):
			with self.subTest(loop=generate.__name__):
				audio = generate()
				power = np.abs(np.fft.rfft(audio)) ** 2
				frequencies = np.fft.rfftfreq(len(audio), 1.0 / SR)
				self.assertLess(power[frequencies > 3500].sum() / power.sum(), 0.0001)

	def test_motor_loops_are_reproducible(self):
		for generate in (buggy_motor, buggy_idle, buggy_coast):
			with self.subTest(loop=generate.__name__):
				np.testing.assert_array_equal(generate(), generate())


if __name__ == "__main__":
	unittest.main()
