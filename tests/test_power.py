"""Power scheduling helpers: validation + pending list. No OS calls."""
import os
import sys
import time
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from pc_service.server import _parse_power, _power_list, POWER


class T(unittest.TestCase):
    def test_parse_ok(self):
        assert _parse_power({"action": "shutdown", "in_minutes": 10}) == ("shutdown", 10, None)
        assert _parse_power({"action": "LOCK"}) == ("lock", 0, None)
        assert _parse_power({"action": "restart", "in_minutes": "30"}) == ("restart", 30, None)

    def test_parse_rejects(self):
        for bad in ({}, {"action": "explode"}, {"action": "shutdown", "in_minutes": -1},
                    {"action": "shutdown", "in_minutes": 9999},
                    {"action": "sleep", "in_minutes": "soon"}):
            a, m, err = _parse_power(bad)
            assert err, bad

    def test_pending_list_shape(self):
        POWER.clear()
        try:
            POWER["shutdown"] = {"timer": None, "at": 1000.0 + 600, "in_minutes": 10, "by": "1.2.3.4"}
            items = _power_list(now=1000.0)
            assert items == [{"action": "shutdown", "in_minutes": 10,
                              "remaining_s": 600, }]
            assert _power_list(now=2000.0)[0]["remaining_s"] == 0
        finally:
            POWER.clear()
