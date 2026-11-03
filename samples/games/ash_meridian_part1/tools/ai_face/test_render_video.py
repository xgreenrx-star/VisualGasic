import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

import render_video as video


class IntroRenderTests(unittest.TestCase):
    def test_wakes_before_scream(self):
        asleep = video.performance(0.06)
        waking = video.performance(0.16)
        watching = video.performance(0.29)
        self.assertEqual(asleep["eyes"], (0, 0))
        self.assertGreater(waking["eyes"][0], waking["eyes"][1])
        self.assertEqual(watching["eyes"], (1, 1))
        self.assertLess(asleep["yaw"], -0.25)
        self.assertAlmostEqual(watching["yaw"], 0)
        self.assertEqual(watching["gaze"], 0)

    def test_crt_has_depth_and_deterministic_static(self):
        black = Image.new("RGB", (video.W, video.H))
        first = np.asarray(video.crt_space(black, 0.12, 0))
        replay = np.asarray(video.crt_space(black, 0.12, 0))
        later = np.asarray(video.crt_space(black, 0.13, 0))
        self.assertTrue(np.array_equal(first, replay))
        self.assertFalse(np.array_equal(first, later))
        self.assertGreater(first[:, :120, 1].mean(), 1)
        self.assertGreater(first[:, :120, 1].std(), 1)

    def test_rendered_eyes_and_turn_change_frames(self):
        video._init("alien", True)
        with tempfile.TemporaryDirectory() as output:
            samples = (60, 120, 180, 285, 600, 959)
            for index in samples:
                video.frame((index, 960, output))
            images = [np.asarray(Image.open(Path(output) / f"f{i:04d}.png"))
                      for i in samples]
            self.assertTrue(all(image.shape == (540, 960, 3) for image in images))
            self.assertGreater(np.abs(images[1].astype(float)-images[2]).mean(), 1)
            self.assertEqual(images[-1].max(), 0)


if __name__ == "__main__":
    unittest.main()
