import unittest, sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from autobrightness.core.curve import lux_to_brightness, Smoother
from autobrightness.core.fusion import fuse

class T(unittest.TestCase):
    def test_curve(self):
        self.assertLess(lux_to_brightness(5), lux_to_brightness(300))
        self.assertEqual(lux_to_brightness(1000), 100)
    def test_smoother_skips_small(self):
        s = Smoother(threshold=4)
        self.assertEqual(s.next(80), 80)
        self.assertIsNone(s.next(82))
    def test_fuse_fallback(self):
        lux, src = fuse(None, 0.0, 300.0)
        self.assertEqual(lux, 300.0)

if __name__ == "__main__":
    unittest.main()
