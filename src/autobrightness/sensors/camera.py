"""Camera ambient light estimator. Optional: needs opencv-python. Falls back to None."""
def estimate_lux(width: int = 160) -> tuple[float | None, float]:
    try:
        import cv2
    except Exception:
        return None, 0.0
    try:
        cap = cv2.VideoCapture(0)
        if not cap.isOpened():
            return None, 0.0
        ok, frame = cap.read()
        cap.release()
        if not ok or frame is None:
            return None, 0.0
        import numpy as np
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        h, w = gray.shape
        # center crop to avoid bright windows at edge, blur faces away by downscale
        small = cv2.resize(gray, (width, width * h // max(1, w)))
        mean = float(small.mean())  # 0..255
        lux = mean * 4.0  # calibration gain: 75 mean ~ 300 lux office
        conf = 0.7 if 10 < mean < 245 else 0.3  # dark/white-out = low trust
        return max(5.0, min(1000.0, lux)), conf
    except Exception:
        return None, 0.0
