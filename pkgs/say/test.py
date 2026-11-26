"""Unit tests for say's queue and daemon, with fake voices, player and gate."""

import importlib.util
import queue
import sys
import threading
import unittest

spec = importlib.util.spec_from_file_location("say", sys.argv.pop(1))
say = importlib.util.module_from_spec(spec)
spec.loader.exec_module(say)

TIMEOUT = 2


class FakeVoices:
    def synth(self, voice, text, speed):
        return 1, f"{voice}:{text}"


class FakePlayer:
    """Each play() blocks until the test finishes it with done()."""

    def __init__(self):
        self.started = queue.Queue()
        self.release = None
        self.lock = threading.Lock()

    def play(self, rate, pcm, cancelled):
        event = threading.Event()
        with self.lock:
            self.release = event
            self.result = True
            if cancelled():
                return False
        self.started.put(pcm)
        event.wait()
        with self.lock:
            return self.result

    def kill(self):
        with self.lock:
            if self.release is not None:
                self.result = False
                self.release.set()

    def next(self):
        return self.started.get(timeout=TIMEOUT)

    def done(self):
        with self.lock:
            self.release.set()

    def silent(self):
        try:
            got = self.started.get(timeout=0.3)
        except queue.Empty:
            return True
        raise AssertionError(f"unexpected playback: {got}")


class Gate:
    def __init__(self):
        self.held = False

    def __call__(self):
        return self.held


class SentenceTest(unittest.TestCase):
    def test_split(self):
        self.assertEqual(
            say.split_sentences('One. "Two!" Three?\n\nFour\nstill four'),
            ["One.", '"Two!"', "Three?", "Four\nstill four"],
        )

    def test_decimal_stays_whole(self):
        self.assertEqual(say.split_sentences("It is 3.5 GB."), ["It is 3.5 GB."])


class TrimTest(unittest.TestCase):
    def test_trims_to_keep(self):
        samples = [0.0] * 50 + [0.5, 0.0]
        self.assertEqual(say.trim_lead(samples, 1000), [0.0] * 10 + [0.5, 0.0])

    def test_silent_and_short(self):
        self.assertEqual(say.trim_lead([0.0] * 50, 1000), [0.0] * 10)
        self.assertEqual(say.trim_lead([0.5], 1000), [0.5])


class QueueTest(unittest.TestCase):
    def test_default_voice(self):
        q = say.Queue()
        self.assertEqual(q.add("Build finished.").voice, "alert")
        self.assertEqual(q.add("One. Two.").voice, "read")
        self.assertEqual(q.add("One. Two.", voice="alert").voice, "alert")

    def test_urgent_jumps_normal_items(self):
        q = say.Queue()
        a = q.add("a")
        u1 = q.add("u1", urgent=True)
        u2 = q.add("u2", urgent=True)
        self.assertEqual(q.items, [u1, u2, a])

    def test_replace_drops_queued_same_tag(self):
        q = say.Queue()
        a = q.add("a", tag="x")
        b = q.add("b", tag="y")
        q.add("c", tag="x")
        c2 = q.add("c2", tag="x", replace=True)
        self.assertEqual(q.items, [b, c2])
        self.assertNotIn(a, q.items)

    def test_replace_keeps_playing_item(self):
        q = say.Queue()
        a = q.add("a", tag="x")
        q.playing = a
        b = q.add("b", tag="x", replace=True)
        self.assertEqual(q.items, [a, b])

    def test_held_and_paused(self):
        q = say.Queue()
        a = q.add("a")
        u = q.add("u", urgent=True)
        self.assertIs(q.next(held=True), u)
        q.remove(u)
        self.assertIsNone(q.next(held=True))
        q.paused = True
        self.assertIsNone(q.next(held=False))
        n = q.add("n", now=True)
        self.assertIs(q.next(held=False), n)
        self.assertEqual(
            [i["state"] for i in q.listing(held=False)], ["queued", "held"]
        )
        self.assertIs(q.items[1], a)


class DaemonTest(unittest.TestCase):
    def setUp(self):
        self.player = FakePlayer()
        self.gate = Gate()
        self.d = say.Daemon(FakeVoices(), self.player, self.gate)
        say.Daemon.RECHECK = 0.05
        threading.Thread(target=self.d.run, daemon=True).start()

    def say(self, text, **kw):
        return self.d.handle({"cmd": "say", "text": text, **kw})["id"]

    def cmd(self, name):
        return self.d.handle({"cmd": name})

    def play(self, *expected):
        for pcm in expected:
            self.assertEqual(self.player.next(), pcm)
            self.player.done()

    def test_queued_in_order_sentence_by_sentence(self):
        self.say("One. Two.")
        self.say("Three.")
        self.play("read:One.", "read:Two.", "alert:Three.")
        self.player.silent()

    def test_now_interrupts_and_resumes_at_sentence(self):
        self.say("One. Two. Three.")
        self.play("read:One.")
        self.assertEqual(self.player.next(), "read:Two.")
        self.say("Now.", now=True)
        self.play("alert:Now.", "read:Two.", "read:Three.")

    def test_stop_drops_current_and_goes_on(self):
        self.say("One. Two.")
        self.say("Next.")
        self.assertEqual(self.player.next(), "read:One.")
        self.assertEqual(self.cmd("stop")["stopped"], 1)
        self.play("alert:Next.")
        self.player.silent()

    def test_clear_empties_queue(self):
        self.say("One. Two.")
        self.say("Next.")
        self.assertEqual(self.player.next(), "read:One.")
        self.assertEqual(self.cmd("clear")["cleared"], 2)
        self.player.silent()
        self.assertEqual(self.cmd("list")["items"], [])

    def test_pause_resume_replays_cut_sentence(self):
        self.say("One. Two.")
        self.play("read:One.")
        self.assertEqual(self.player.next(), "read:Two.")
        self.cmd("pause")
        self.player.silent()
        listing = self.cmd("list")
        self.assertTrue(listing["paused"])
        self.assertEqual(listing["items"][0]["sentence"], 1)
        self.cmd("resume")
        self.play("read:Two.")
        self.player.silent()

    def test_stop_while_paused_drops_cut_item(self):
        self.say("One. Two.")
        self.say("Next.")
        self.play("read:One.")
        self.assertEqual(self.player.next(), "read:Two.")
        self.cmd("pause")
        self.cmd("stop")
        self.cmd("resume")
        self.play("alert:Next.")

    def test_tag_replace(self):
        self.say("Busy.")
        self.assertEqual(self.player.next(), "alert:Busy.")
        self.say("Old.", tag="attn:1")
        self.say("New.", tag="attn:1", replace=True)
        self.player.done()
        self.play("alert:New.")
        self.player.silent()

    def test_held_items_wait_urgent_speaks(self):
        self.gate.held = True
        self.say("Normal.")
        self.player.silent()
        self.assertEqual(self.cmd("list")["items"][0]["state"], "held")
        self.say("Alarm.", urgent=True)
        self.play("alert:Alarm.")
        self.player.silent()
        self.gate.held = False
        self.play("alert:Normal.")

    def test_hold_stops_after_current_sentence(self):
        self.say("One. Two.")
        self.assertEqual(self.player.next(), "read:One.")
        self.gate.held = True
        self.player.done()
        self.player.silent()
        self.gate.held = False
        self.play("read:Two.")

    def test_list(self):
        self.say("One. Two.", tag="t")
        self.player.next()
        self.say("Next.")
        items = self.cmd("list")["items"]
        self.assertEqual([i["state"] for i in items], ["playing", "queued"])
        self.assertEqual(items[0]["tag"], "t")
        self.assertEqual(items[0]["sentences"], 2)


if __name__ == "__main__":
    unittest.main()
