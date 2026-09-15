import math

def lux_to_brightness(lux: float, min_b: int = 10, max_b: int = 100) -> int:
    """Log curve: 5 lux -> min_b, 1000 lux -> max_b."""
    lux = max(5.0, min(1000.0, float(lux)))
    lo, hi = math.log10(6), math.log10(1001)
    t = (math.log10(1 + lux) - lo) / (hi - lo)
    return int(min_b + (max_b - min_b) * max(0.0, min(1.0, t)))

class Smoother:
    def __init__(self, alpha: float = 0.3, threshold: int = 4):
        self.alpha = alpha
        self.threshold = threshold
        self.value: float | None = None

    def next(self, target: int) -> int | None:
        if self.value is None:
            self.value = float(target)
            return target
        self.value += self.alpha * (target - self.value)
        if abs(target - self.value) < self.threshold:
            return None  # no flicker: skip small change
        return int(self.value)
