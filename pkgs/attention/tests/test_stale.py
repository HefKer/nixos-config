"""Unit tests for stale tabs, without herdr, nvim or DMS."""

import os
import tempfile
import unittest
from pathlib import Path

from attention import agents, stale
from attention.herdr import Agent

DAY = 86400


def agent(tab="t1", status="idle", completion=1, kind="claude", session_id="s1", pane=None):
    return Agent("default", "/sock", pane or f"p-{tab}", f"term-{tab}", kind, status, 1, completion, session_id, "Long title", "", False, tab, "/repo")


def snap(*tabs, focused=None):
    return {
        "workspaces": [{"workspace_id": "w1", "label": "repo"}],
        "tabs": [{"tab_id": t, "workspace_id": "w1", "label": label, "focused": t == focused} for t, label in tabs],
        "panes": [{"pane_id": f"p-{t}", "tab_id": t} for t, _ in tabs] + [{"pane_id": f"prompt-{t}", "tab_id": t} for t, _ in tabs],
    }


class Ops:
    Error = RuntimeError

    def __init__(self):
        self.renamed, self.closed_tabs, self.notified = [], [], []

    def rename(self, path, tab_id, label):
        self.renamed.append((tab_id, label))

    def close(self, path, tab_id):
        self.closed_tabs.append(tab_id)

    def closed(self, mark):
        self.notified.append(mark)


class Candidates(unittest.TestCase):
    def ids(self, live, open_ids=()):
        tabs = [(a.tab_id, "1 · x") for a in live]
        return [tab["tab_id"] for tab, _, _ in stale.candidates(snap(*dict(tabs).items()), live, set(open_ids), agents.mark_key)]

    def test_a_handled_idle_claude_can_be_stale(self):
        self.assertEqual(self.ids([agent("t1")]), ["t1"])

    def test_an_open_item_blocked_or_working_agent_is_not(self):
        done = agent("t1", "done")
        self.assertEqual(self.ids([done], [agents.mark_key(done)]), [])
        self.assertEqual(self.ids([agent("t2", "blocked")]), [])
        self.assertEqual(self.ids([agent("t3", "working")]), [])

    def test_a_tab_with_two_agents_another_agent_or_no_session_is_not(self):
        self.assertEqual(self.ids([agent("t1"), agent("t1", pane="p-other")]), [])
        self.assertEqual(self.ids([agent("t2", kind="codex")]), [])
        self.assertEqual(self.ids([agent("t3", session_id=None)]), [])

    def test_other_panes_come_with_the_tab(self):
        _, _, others = next(stale.candidates(snap(("t1", "1 · x")), [agent("t1")], set(), agents.mark_key))
        self.assertEqual([p["pane_id"] for p in others], ["prompt-t1"])


class Quiet(unittest.TestCase):
    def info(self, *names):
        return {"foreground_processes": [{"name": n, "pid": i} for i, n in enumerate(names)]}

    def test_an_idle_shell_is_quiet(self):
        self.assertTrue(stale.quiet(self.info("fish"), lambda pid: False))

    def test_nvim_is_quiet_only_without_unsaved_buffers(self):
        self.assertTrue(stale.quiet(self.info("nvim"), lambda pid: True))
        self.assertFalse(stale.quiet(self.info("nvim"), lambda pid: False))

    def test_any_other_program_or_nothing_known_is_alive(self):
        self.assertFalse(stale.quiet(self.info("lazygit"), lambda pid: True))
        self.assertFalse(stale.quiet(self.info("fish", "make"), lambda pid: True))
        self.assertFalse(stale.quiet({}, lambda pid: True))


class Labels(unittest.TestCase):
    def test_the_mark_sits_after_the_position(self):
        numbered, body = stale.unmarked("4 · #166 PSI")
        self.assertEqual((numbered, body), (True, "#166 PSI"))
        self.assertEqual(stale.marked_label(3, numbered, body), f"3 · {stale.MARK} #166 PSI")
        self.assertEqual(stale.marked_label(1, *stale.unmarked("notes")), f"{stale.MARK} notes")

    def test_positions_count_within_a_space_and_skip_closing_tabs(self):
        s = snap(("a", ""), ("b", ""), ("c", ""))
        s["tabs"].append({"tab_id": "d", "workspace_id": "w2"})
        self.assertEqual(stale.positions(s), {"a": 1, "b": 2, "c": 3, "d": 1})
        self.assertEqual(stale.positions(s, {"a"}), {"b": 1, "c": 2, "d": 1})


class LastInput(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        os.environ["XDG_STATE_HOME"] = str(self.dir)
        (self.dir / "nvim/claude-drafts").mkdir(parents=True)
        self.transcript = self.dir / "s1.jsonl"
        self.transcript.write_text("")
        os.utime(self.transcript, (100, 100))

    def test_the_later_of_transcript_and_draft(self):
        self.assertEqual(stale.last_input(agent(), self.transcript), 100)
        draft = self.dir / "nvim/claude-drafts/s1.md"
        draft.write_text("half a prompt")
        os.utime(draft, (200, 200))
        self.assertEqual(stale.last_input(agent(), self.transcript), 200)

    def test_a_draft_keyed_to_the_pane_keeps_the_tab(self):
        (self.dir / "nvim/claude-drafts/pane-p-t1.md").write_text("x")
        self.assertIsNone(stale.last_input(agent(), self.transcript))


class Sweep(unittest.TestCase):
    def setUp(self):
        self.marks, self.ops = {}, Ops()

    def sweep(self, s, live, now, verdict=True, unreachable=()):
        snaps = {"default": ("/sock", s)} if s is not None else {}
        judge = lambda path, a, others: "/home/u/.claude" if verdict else None  # noqa: E731
        stale.sweep(self.marks, snaps, set(unreachable), live, set(), agents.mark_key, now, judge, self.ops)

    def test_marked_for_a_day_then_closed_with_a_notification(self):
        s, live = snap(("t1", "1 · Long")), [agent("t1")]
        self.sweep(s, live, 0)
        self.assertEqual(self.ops.renamed, [("t1", f"1 · {stale.MARK} Long")])
        s["tabs"][0]["label"] = f"1 · {stale.MARK} Long"
        self.sweep(s, live, DAY - 1)
        self.assertEqual(self.ops.closed_tabs, [])
        self.sweep(s, live, DAY)
        self.assertEqual(self.ops.closed_tabs, ["t1"])
        self.assertEqual(self.marks, {})
        (mark,) = self.ops.notified
        self.assertEqual((mark["title"], mark["space"], mark["session_id"], mark["config"], mark["cwd"]), ("Long title", "repo", "s1", "/home/u/.claude", "/repo"))

    def test_a_focused_tab_is_kept_marked(self):
        live = [agent("t1")]
        self.sweep(snap(("t1", "1 · x")), live, 0)
        self.sweep(snap(("t1", "1 · x"), focused="t1"), live, 2 * DAY)
        self.assertEqual(self.ops.closed_tabs, [])

    def test_a_tab_no_longer_stale_is_handed_back_to_auto_title(self):
        s, live = snap(("t1", "1 · x")), [agent("t1")]
        self.sweep(s, live, 0)
        self.sweep(s, live, 10, verdict=False)
        self.assertEqual(self.ops.renamed[-1], ("t1", ""))
        self.assertEqual(self.marks, {})
        self.sweep(snap(("t1", "1 · x")), live, 20)
        self.sweep(snap(("t1", "1 · x")), [agent("t1", "working")], 30)
        self.assertEqual(self.ops.renamed[-1], ("t1", ""))
        self.assertEqual(self.marks, {})

    def test_a_marked_tab_follows_its_position(self):
        live = [agent("t1"), agent("t2")]
        self.sweep(snap(("t1", "1 · a"), ("t2", "2 · b")), live[1:], 0)
        self.assertEqual(self.ops.renamed, [("t2", f"2 · {stale.MARK} b")])
        self.sweep(snap(("t2", f"2 · {stale.MARK} b")), live[1:], 10)
        self.assertEqual(self.ops.renamed[-1], ("t2", f"1 · {stale.MARK} b"))

    def test_an_unreachable_session_keeps_its_marks_a_gone_one_drops_them(self):
        self.sweep(snap(("t1", "1 · x")), [agent("t1")], 0)
        self.sweep(None, [], 2 * DAY, unreachable={"default"})
        self.assertEqual(len(self.marks), 1)
        self.sweep(None, [], 2 * DAY)
        self.assertEqual(self.marks, {})
        self.assertEqual(self.ops.closed_tabs, [])

    def test_a_closed_tab_drops_its_mark_without_a_rename(self):
        self.sweep(snap(("t1", "1 · x")), [agent("t1")], 0)
        self.sweep(snap(), [], 10)
        self.assertEqual(self.marks, {})
        self.assertEqual(len(self.ops.renamed), 1)

    def test_a_failed_close_keeps_the_mark(self):
        self.sweep(snap(("t1", "1 · x")), [agent("t1")], 0)

        def refuse(path, tab_id):
            raise RuntimeError("busy")

        self.ops.close = refuse
        self.sweep(snap(("t1", "1 · x")), [agent("t1")], DAY)
        self.assertEqual(len(self.marks), 1)
        self.assertEqual(self.ops.notified, [])


if __name__ == "__main__":
    unittest.main()
