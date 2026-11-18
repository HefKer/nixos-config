"""Unit tests for notify-focus's id tracking and window choice, without a bus or niri."""

import importlib.util
import sys
import unittest

spec = importlib.util.spec_from_file_location("notify_focus", sys.argv.pop(1))
nf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nf)


def notify(sender, cookie, hints):
    return {
        "type": "method_call", "sender": sender, "destination": ":1.1",
        "member": "Notify", "cookie": cookie,
        "payload": {"data": ["app", 0, "", "s", "b", ["default", "Open"], hints, -1]},
    }


def reply(destination, cookie, nid):
    return {"type": "method_return", "sender": ":1.1", "destination": destination,
            "reply_cookie": cookie, "payload": {"data": [nid]}}


def invoked(nid, action="default"):
    return {"type": "signal", "member": "ActionInvoked", "payload": {"data": [nid, action]}}


class TrackerTest(unittest.TestCase):
    def setUp(self):
        self.lookups = []
        self.t = nf.Tracker(lambda name: self.lookups.append(name) or 77)

    def test_sender_pid_hint(self):
        self.t.handle(notify(":1.5", 10, {"sender-pid": {"type": "x", "data": 42}}))
        self.t.handle(reply(":1.5", 10, 7))
        self.assertEqual(self.t.handle(invoked(7)), 42)
        self.assertEqual(self.lookups, [])

    def test_caller_pid_without_hint(self):
        self.t.handle(notify(":1.5", 10, {}))
        self.t.handle(reply(":1.5", 10, 7))
        self.assertEqual(self.t.handle(invoked(7)), 77)
        self.assertEqual(self.lookups, [":1.5"])

    def test_other_action_ignored(self):
        self.t.handle(notify(":1.5", 10, {"sender-pid": {"data": 42}}))
        self.t.handle(reply(":1.5", 10, 7))
        self.assertIsNone(self.t.handle(invoked(7, "mark-read")))

    def test_unknown_id_and_unrelated_reply(self):
        self.t.handle(notify(":1.5", 10, {"sender-pid": {"data": 42}}))
        self.t.handle(reply(":1.6", 10, 7))
        self.assertIsNone(self.t.handle(invoked(7)))

    def test_replaced_id_takes_new_pid(self):
        self.t.handle(notify(":1.5", 10, {"sender-pid": {"data": 42}}))
        self.t.handle(reply(":1.5", 10, 7))
        self.t.handle(notify(":1.6", 3, {"sender-pid": {"data": 43}}))
        self.t.handle(reply(":1.6", 3, 7))
        self.assertEqual(self.t.handle(invoked(7)), 43)


class PickWindowTest(unittest.TestCase):
    def test_most_recently_focused_of_pid(self):
        windows = [
            {"id": 1, "pid": 42, "focus_timestamp": {"secs": 5, "nanos": 0}},
            {"id": 2, "pid": 42, "focus_timestamp": {"secs": 9, "nanos": 0}},
            {"id": 3, "pid": 50, "focus_timestamp": {"secs": 99, "nanos": 0}},
        ]
        self.assertEqual(nf.pick_window(windows, 42)["id"], 2)

    def test_ancestor_window(self):
        windows = [{"id": 1, "pid": 10}]
        parents = {30: 20, 20: 10}
        self.assertEqual(nf.pick_window(windows, 30, parents.get)["id"], 1)

    def test_no_window(self):
        self.assertIsNone(nf.pick_window([{"id": 1, "pid": 10}], 30, lambda p: None))


if __name__ == "__main__":
    unittest.main()
