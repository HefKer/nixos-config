"""Unit tests for the queue model, without herdr, DMS or Jev."""

import json
import os
import tempfile
import unittest
from pathlib import Path

os.environ["ATTENTION_STATE_DIR"] = tempfile.mkdtemp()

from attention import agents, bands, claude, classify, messages, store  # noqa: E402
from attention.herdr import Agent  # noqa: E402
from attention.ranking import build, requeue  # noqa: E402


def agent(terminal="t1", status="done", completion=1, state=1, session="default", in_view=False):
    return Agent(session, "/sock", f"p-{terminal}", terminal, "claude", status, state, completion, None, "title", "ws · tab", in_view)


def idle(_):
    return False


def ids(queue):
    return [item["id"] for item in queue]


class Queue(unittest.TestCase):
    def setUp(self):
        with store.locked() as state:
            state.agents.clear()
            state.messages.clear()

    def build(self, live, now, busy=idle):
        with store.locked() as state:
            return build(state, live, now, busy)

    def test_bands_rank_before_age(self):
        with store.locked() as state:
            state.messages["m/later"] = {"id": "m/later", "kind": "message", "band": bands.LATER, "order": 0, "title": "", "detail": ""}
            state.messages["m/urgent"] = {"id": "m/urgent", "kind": "message", "band": bands.URGENT, "order": 50, "title": "", "detail": ""}
            state.messages["m/reply"] = {"id": "m/reply", "kind": "message", "band": bands.REPLY_SOON, "order": 1, "title": "", "detail": ""}
        queue = self.build([agent("done", "done", 3), agent("blocked", "blocked")], 10)
        self.assertEqual(
            ids(queue),
            ["m/urgent", "default/blocked/blocked/1", "m/reply", "default/done/done/3", "m/later"],
        )

    def test_oldest_first_within_a_band_and_requeue_goes_behind_peers(self):
        self.build([agent("a")], 1)
        queue = self.build([agent("a"), agent("b")], 2)
        self.assertEqual(ids(queue), ["default/a/done/1", "default/b/done/1"])
        with store.locked() as state:
            requeue(state, queue[0], 3)
        self.assertEqual(ids(self.build([agent("a"), agent("b")], 4)), ["default/b/done/1", "default/a/done/1"])

    def test_done_item_survives_herdr_marking_it_idle(self):
        self.build([agent("a", "done")], 1)
        self.assertEqual(len(self.build([agent("a", "idle")], 2)), 1)

    def test_idle_agent_never_seen_done_is_no_item(self):
        self.assertEqual(self.build([agent("a", "idle")], 1), [])

    def test_prompting_handles_a_done_agent(self):
        self.build([agent("a", "done", 1)], 1)
        self.assertEqual(self.build([agent("a", "working", 1)], 2), [])
        self.assertEqual(self.build([agent("a", "idle", 1)], 3), [])

    def test_blocked_agent_leaves_once_unblocked(self):
        self.assertEqual(len(self.build([agent("a", "blocked", state=4)], 1)), 1)
        self.assertEqual(self.build([agent("a", "working", state=5)], 2), [])

    def test_restarted_herdr_leaves_no_stale_items(self):
        self.build([agent("a", "done", 7), agent("b", "blocked")], 1)
        # A restarted server restores its panes idle, with new terminal ids and no completion yet.
        self.assertEqual(self.build([agent("a2", "idle", None), agent("b2", "idle", None)], 2), [])
        with store.locked() as state:
            self.assertEqual(state.agents, {})

    def test_a_session_that_does_not_answer_keeps_its_marks(self):
        self.build([agent("a", "done", session="work"), agent("b", "done")], 1)
        with store.locked() as state:
            queue = build(state, [agent("b", "done")], 2, idle, unreachable={"work"})
        self.assertEqual(ids(queue), ["default/b/done/1"])
        self.assertEqual(ids(self.build([agent("a", "idle", session="work"), agent("b", "idle")], 3)), ["work/a/done/1", "default/b/done/1"])

    def test_background_work_keeps_a_done_agent_out(self):
        self.assertEqual(self.build([agent("a")], 1, busy=lambda _: True), [])
        self.assertEqual(len(self.build([agent("a")], 2)), 1)

    def test_watching_five_seconds_handles_a_done_agent(self):
        queue = self.build([agent("a")], 0)
        with store.locked() as state:
            for now in range(0, 6):
                agents.watched(state.agents, queue[0], True, now)
        self.assertEqual(self.build([agent("a")], 6), [])

    def test_leaving_before_five_seconds_restarts_the_count(self):
        queue = self.build([agent("a")], 0)
        with store.locked() as state:
            for now, seeing in [(0, True), (1, True), (2, True), (3, False), (4, True), (5, True), (6, True)]:
                agents.watched(state.agents, queue[0], seeing, now)
        self.assertEqual(len(self.build([agent("a")], 7)), 1)

    def test_watching_does_not_handle_a_blocked_agent(self):
        queue = self.build([agent("a", "blocked")], 0)
        with store.locked() as state:
            for now in range(0, 10):
                agents.watched(state.agents, queue[0], True, now)
        self.assertEqual(len(self.build([agent("a", "blocked")], 10)), 1)

    def test_going_to_a_message_handles_it(self):
        item, _ = messages.ingest({"summary": "Sam", "body": "hi", "id": 4}, 1, place=lambda _: "reply_soon")
        self.assertEqual(ids(self.build([], 2)), [item["id"]])
        messages.invoke = lambda _id, _summary: True
        messages.go(item)
        self.assertEqual(self.build([], 3), [])

    def test_a_notification_that_is_no_item_is_not_stored(self):
        self.assertEqual(messages.ingest({"summary": "x", "body": "y"}, 1, place=lambda _: None), (None, False))
        self.assertEqual(self.build([], 2), [])


def discord(summary, body="hi", dms_id=1):
    return {"appName": "vesktop", "summary": summary, "body": body, "id": dms_id}


def phone(summary, body="hi"):
    return {"desktopEntry": "org.kde.kdeconnect.daemon", "summary": summary, "body": body}


class Conversations(unittest.TestCase):
    def setUp(self):
        with store.locked() as state:
            state.agents.clear()
            state.messages.clear()
        self.now = 0
        self.invoked = []
        self.real_invoke = messages.invoke
        messages.invoke = lambda dms_id, summary: self.invoked.append((dms_id, summary)) or True

    def tearDown(self):
        messages.invoke = self.real_invoke

    def ingest(self, notification, band="later"):
        self.now += 1
        return messages.ingest(notification, self.now, place=lambda _: band)

    def queue(self):
        with store.locked() as state:
            return build(state, [], self.now + 1, idle)

    def test_a_burst_from_one_channel_is_one_item_that_one_go_handles(self):
        for number in range(1, 6):
            self.ingest(discord("bob (#general, Friends)", f"message {number}", number))
        self.ingest(discord("alice", "hello", 9))
        queue = self.queue()
        self.assertEqual([(item["title"], item["count"]) for item in queue], [("bob (#general, Friends)", 5), ("alice", 1)])
        self.assertEqual(queue[0]["detail"], "message 5")
        self.assertEqual(messages.heading(queue[0]), "bob (#general, Friends) · 5 messages")
        self.assertEqual(messages.heading(queue[1]), "alice")
        messages.go(queue[0])
        self.assertEqual(self.invoked, [(5, "bob (#general, Friends)")])
        self.assertEqual([item["title"] for item in self.queue()], ["alice"])

    def test_only_a_new_item_or_a_raised_band_pops_up(self):
        first, pops_up = self.ingest(discord("bob (#general, Friends)"), "reply_soon")
        self.assertTrue(pops_up)
        self.assertEqual(self.ingest(discord("bob (#general, Friends)"), "reply_soon")[1], False)
        self.assertEqual(self.ingest(discord("bob (#general, Friends)"), "later")[1], False)
        self.assertEqual(self.queue()[0]["band"], bands.REPLY_SOON)
        raised, pops_up = self.ingest(discord("bob (#general, Friends)"), "urgent")
        self.assertTrue(pops_up)
        self.assertEqual((raised["id"], raised["band"], raised["count"]), (first["id"], bands.URGENT, 4))
        self.assertEqual(self.ingest(discord("bob (#general, Friends)"), "urgent")[1], False)

    def test_a_joined_item_keeps_its_first_message_s_place(self):
        self.ingest(discord("bob (#general, Friends)"))
        self.ingest(discord("alice"))
        self.ingest(discord("bob (#general, Friends)"))
        self.assertEqual([(item["title"], item["order"]) for item in self.queue()], [("bob (#general, Friends)", 1), ("alice", 2)])

    def test_a_conversation_is_the_channel_not_the_sender(self):
        self.ingest(discord("bob (#general, Friends)"))
        self.ingest(discord("carol (#general, Friends)"))
        self.ingest(discord("bob (#random, Friends)"))
        self.ingest(discord("bob (#general, Rivals)"))
        self.ingest(discord("bob (router nerds)"))
        self.ingest(discord("dan (router nerds)"))
        self.ingest(discord("bob"))
        self.ingest(discord("⁨bob⁩"))
        self.assertEqual(
            [(item["title"], item["count"]) for item in self.queue()],
            [("carol (#general, Friends)", 2), ("bob (#random, Friends)", 1), ("bob (#general, Rivals)", 1), ("dan (router nerds)", 2), ("bob", 2)],
        )

    def test_phone_notifications_join_by_app_and_title(self):
        self.ingest(phone("WhatsApp: Mum", "one"))
        self.ingest(phone("WhatsApp: Mum", "two"))
        self.ingest(phone("WhatsApp: Dad"))
        self.ingest(phone("Signal: Mum"))
        self.ingest(discord("WhatsApp: Mum"))
        self.assertEqual(
            [(item["title"], item["count"], item["source"]) for item in self.queue()],
            [("WhatsApp: Mum", 2, "phone"), ("WhatsApp: Dad", 1, "phone"), ("Signal: Mum", 1, "phone"), ("WhatsApp: Mum", 1, "discord")],
        )

    def test_a_muted_or_non_item_notification_leaves_an_open_item_alone(self):
        self.ingest(discord("bob (#general, Friends)", "first"))
        before = self.queue()
        self.assertEqual(self.ingest(discord("bob (#general, Friends)", "advert"), None), (None, False))
        self.assertEqual(self.queue(), before)

    def test_an_item_stored_before_conversations_still_lists_and_goes(self):
        with store.locked() as state:
            state.messages["message/old"] = {"id": "message/old", "kind": "message", "band": bands.LATER, "order": 0, "source": "discord", "dms_id": 3, "title": "bob", "detail": "old"}
        new, pops_up = self.ingest(discord("bob"))
        self.assertTrue(pops_up)
        queue = self.queue()
        self.assertEqual([item["id"] for item in queue], ["message/old", new["id"]])
        self.assertEqual(messages.heading(queue[0]), "bob")
        messages.go(queue[0])
        self.assertEqual(self.invoked, [(3, "bob")])
        self.assertEqual([item["id"] for item in self.queue()], [new["id"]])


class Background(unittest.TestCase):
    def result(self, stamp, text):
        content = [{"type": "tool_result", "tool_use_id": "x", "content": text}]
        return json.dumps({"type": "user", "timestamp": stamp, "message": {"role": "user", "content": content}})

    def queued(self, stamp, text):
        return json.dumps({"type": "queue-operation", "operation": "enqueue", "timestamp": stamp, "content": text})

    def test_launched_and_unfinished_tasks_are_pending(self):
        lines = [
            self.result("2026-11-12T10:00:00Z", [{"type": "text", "text": "Async agent launched successfully. (internal)\nagentId: a1 (x)"}]),
            self.result("2026-11-12T10:00:01Z", "Command running in background with ID: b2. Output is"),
            self.result("2026-11-12T10:00:02Z", "Monitor started (task m3, timeout 9ms)."),
            self.queued("2026-11-12T10:00:03Z", "<task-notification>\n<task-id>a1</task-id>\n<status>completed</status>\n</task-notification>"),
            self.queued("2026-11-12T10:00:04Z", "<task-notification>\n<task-id>m3</task-id>\n<event>line</event>\n</task-notification>"),
        ]
        self.assertEqual(claude.pending(lines, 0), {"b2", "m3"})

    def test_a_quoted_marker_launches_nothing(self):
        lines = [
            self.result("2026-11-12T10:00:00Z", "grep: running in background with ID: b9. Output"),
            json.dumps({"type": "assistant", "timestamp": "2026-11-12T10:00:01Z", "message": {"content": [{"type": "text", "text": "Command running in background with ID: b8."}]}}),
        ]
        self.assertEqual(claude.pending(lines, 0), set())

    def test_launches_before_the_process_started_died_with_it(self):
        lines = [self.result("2026-11-12T10:00:01Z", "Command running in background with ID: b2. Output")]
        started = claude.timestamp_ms(json.loads(lines[0])) + 1
        self.assertEqual(claude.pending(lines, started), set())

    def test_live_session_finds_a_running_process(self):
        root = Path(tempfile.mkdtemp())
        (root / "sessions").mkdir()
        (root / "sessions/1.json").write_text(json.dumps({"pid": os.getpid(), "sessionId": "s", "startedAt": 5}))
        (root / "sessions/2.json").write_text(json.dumps({"pid": 2**22 + 7, "sessionId": "dead", "startedAt": 5}))
        os.environ["ATTENTION_CLAUDE_DIRS"] = str(root)
        try:
            self.assertEqual(claude.live_session("s"), (root, 5))
            self.assertIsNone(claude.live_session("dead"))
        finally:
            del os.environ["ATTENTION_CLAUDE_DIRS"]


def answers(**overrides):
    base = {"by_person": 0.95, "waits_on_reply": 0.1, "someone_blocked": 0.05, "needs_answer_soon": 0.1, "about_work": 0.1}
    return base | overrides


class Classify(unittest.TestCase):
    def test_truth_table(self):
        self.assertIsNone(classify.band(answers(by_person=0.1), False))
        self.assertEqual(classify.band(answers(by_person=0.5), False), "later")
        self.assertEqual(classify.band(answers(), False), "later")
        self.assertEqual(classify.band(answers(waits_on_reply=0.9), False), "reply_soon")
        self.assertEqual(classify.band(answers(someone_blocked=0.9), True), "urgent")
        self.assertEqual(classify.band(answers(someone_blocked=0.9, about_work=0.9), False), "urgent")
        self.assertEqual(classify.band(answers(someone_blocked=0.9), False), "reply_soon")
        self.assertEqual(classify.band(answers(needs_answer_soon=0.9, waits_on_reply=0.9), False), "reply_soon")
        self.assertEqual(classify.band(answers(needs_answer_soon=0.9), True), "urgent")

    def test_discord_titles(self):
        self.assertEqual(classify.discord_origin("⁨John⁩ (⁨#hack⁩, ⁨HackHCC⁩)"), ("John", "#hack", "HackHCC"))
        self.assertEqual(classify.discord_origin("⁨Big⁩ (⁨router nerds⁩)"), ("Big", "router nerds", None))
        self.assertEqual(classify.discord_origin("⁨Sam⁩"), ("Sam", None, None))

    def test_only_discord_and_the_phone_are_sources(self):
        self.assertEqual(classify.place({"appName": "rebuild", "body": "x"}, {}, asker=lambda s: answers()), None)
        self.assertEqual(classify.place({"appName": "vesktop", "summary": "Sam", "body": "x"}, {}, asker=lambda s: answers()), "later")

    def test_unreachable_classifier_means_later(self):
        def down(_):
            raise classify.Unreachable("offline")

        self.assertEqual(classify.place({"appName": "vesktop", "summary": "Sam", "body": "help"}, {}, asker=down), "later")

    def test_rules_filter_before_the_classifier(self):
        book = {"mute": {"servers": ["Spam Hub"], "senders": ["Bot"], "phone_apps": ["Instagram"]}}
        never = lambda _: self.fail("asked Jev")  # noqa: E731
        self.assertIsNone(classify.place({"appName": "vesktop", "summary": "A (#x, Spam Hub)", "body": "y"}, book, never))
        self.assertIsNone(classify.place({"appName": "vesktop", "summary": "Bot", "body": "y"}, book, never))
        self.assertIsNone(classify.place({"desktopEntry": "org.kde.kdeconnect.daemon", "summary": "Instagram: z", "body": "y"}, book, never))
        self.assertIsNone(classify.place({"appName": "vesktop", "summary": "Sam", "body": ""}, book, never))

    def test_contacts_reach_the_state_and_the_table(self):
        book = {"people": {"Alex": {"relationship": "coworker", "work": True}}, "servers": {"Lab": {"note": "work team"}}}
        seen = {}

        def asker(state):
            seen.update(state)
            return answers(someone_blocked=0.9)

        band = classify.place({"appName": "vesktop", "summary": "⁨Alex⁩ (⁨#dev⁩, ⁨Lab⁩)", "body": "blocked on your review"}, book, asker)
        self.assertEqual(band, "urgent")
        self.assertEqual(seen["sender"], {"name": "Alex", "relationship": "coworker"})
        self.assertEqual(seen["where"], "#dev in the server Lab")
        self.assertEqual(seen["server"], {"name": "Lab", "note": "work team"})


if __name__ == "__main__":
    unittest.main()
