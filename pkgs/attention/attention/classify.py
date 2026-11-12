"""Placing a third-party notification: rules first, then Jev's judgments, then a truth table in code.

Every question, threshold and the table itself live here, so they can be read and tuned together.
"""

import json
import os
import re
import shutil
import subprocess
import tomllib
from pathlib import Path

YES, NO = 0.7, 0.3

# Each one judgment a person makes at a glance; code combines them in `band`.
QUESTIONS = {
    "by_person": {
        "type": "noul",
        "instructions": "Was `message` typed by a person to the people it was sent to?",
        "criteria": {
            "true": "A person wrote it, such as a chat message, a reply or a shared link with a comment",
            "false": "It is automated, promotional or bulk: a bot post, an advert, a giveaway or a scam",
        },
    },
    "waits_on_reply": {
        "type": "noul",
        "instructions": "Does `message` wait on a reply from the reader?",
        "criteria": {
            "true": "It asks the reader a question, or for a decision, help or a favour",
            "false": "It shares something to see, read or laugh at, or says something that needs no reply",
        },
    },
    "someone_blocked": {
        "type": "noul",
        "instructions": "Does `message` say that someone is stuck, or waiting, until the reader acts?",
    },
    "needs_answer_soon": {
        "type": "noul",
        "instructions": "Does `message` need an answer within the next hour?",
    },
    "about_work": {
        "type": "noul",
        "instructions": "Is `message` about work, school or a project with a deadline?",
    },
}


def band(answers, work_contact):
    """The truth table: Jev's answers and what code knows about the sender, to a band or None.

    None means the notification produces no item. A Noul between NO and YES counts as no, so an
    unsettled question never lifts an item above Later.
    """
    if answers["by_person"] < NO:
        return None
    if answers["by_person"] < YES:
        return "later"
    work = work_contact or answers["about_work"] >= YES
    if answers["someone_blocked"] >= YES and work:
        return "urgent"
    if answers["needs_answer_soon"] >= YES and work:
        return "urgent"
    if answers["waits_on_reply"] >= YES or answers["someone_blocked"] >= YES:
        return "reply_soon"
    return "later"


# Sources --------------------------------------------------------------------------------------

ISOLATES = dict.fromkeys(map(ord, "⁦⁧⁨⁩"))
DISCORD_TITLE = re.compile(r"^(?P<sender>.+?) \((?P<where>.+)\)$")


def source(notification):
    app, entry = notification.get("appName", ""), notification.get("desktopEntry", "")
    if "vesktop" in (app.lower(), entry.lower()):
        return "discord"
    if entry == "org.kde.kdeconnect.daemon" or app == "KDE Connect":
        return "phone"
    return None


def discord_origin(summary):
    """(sender, channel, server) from vesktop's title: `Sender`, `Sender (Group)` or `Sender (#channel, Server)`."""
    summary = summary.translate(ISOLATES).strip()
    match = DISCORD_TITLE.match(summary)
    if not match:
        return summary, None, None
    where = match["where"]
    if where.startswith("#") and ", " in where:
        channel, server = where.split(", ", 1)
        return match["sender"], channel, server
    return match["sender"], where, None


# Contacts ---------------------------------------------------------------------------------------


def contacts_path():
    return Path(os.environ.get("ATTENTION_CONTACTS") or Path.home() / "polaris/attention-contacts.toml")


def contacts():
    """The private contacts file: [people.<name>] and [servers.<name>] with relationship/work/note,
    and [mute] lists of servers, senders and phone_apps. Missing or unreadable means empty."""
    try:
        with open(contacts_path(), "rb") as handle:
            return tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError):
        return {}


def describe(notification, book):
    """(state for Jev, whether code knows the sender as a work contact), or None when a rule mutes it."""
    kind = source(notification)
    mute = book.get("mute", {})
    body = notification.get("body", "").translate(ISOLATES).strip()
    if not body:
        return None
    if kind == "discord":
        sender, channel, server = discord_origin(notification.get("summary", ""))
        if server in mute.get("servers", []) or sender in mute.get("senders", []):
            return None
        person = book.get("people", {}).get(sender, {})
        place = book.get("servers", {}).get(server, {}) if server else {}
        state = {
            "source": "Discord",
            "sender": {"name": sender, "relationship": person.get("relationship", "unknown"), "note": person.get("note")},
            "where": (f"{channel} in the server {server}" if server else f"the group chat {channel}") if channel else "a direct message",
            "server": {"name": server, "note": place.get("note")} if server else None,
            "message": body,
        }
        return prune(state), bool(person.get("work") or place.get("work"))
    title = notification.get("summary", "").translate(ISOLATES).strip()
    app = title.split(":", 1)[0] if ":" in title else ""
    if app and app in mute.get("phone_apps", []):
        return None
    person = book.get("people", {}).get(title, {})
    state = {
        "source": "a phone notification",
        "title": title,
        "sender": {"relationship": person.get("relationship"), "note": person.get("note")} if person else None,
        "message": body,
    }
    return prune(state), bool(person.get("work"))


def prune(value):
    """Drops empty fields, which Jev could read as a signal."""
    if isinstance(value, dict):
        pruned = {k: prune(v) for k, v in value.items()}
        return {k: v for k, v in pruned.items() if v not in (None, "", {}, [])}
    return value


# Jev ------------------------------------------------------------------------------------------


class Unreachable(Exception):
    pass


def jev():
    return shutil.which("jev") or str(Path.home() / ".local/bin/jev")


def ask(state):
    body = {"state": state, "questions": QUESTIONS}
    try:
        done = subprocess.run([jev(), "ask"], input=json.dumps(body), capture_output=True, text=True, timeout=30, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise Unreachable(str(error)) from None
    if done.returncode:
        raise Unreachable(done.stderr.strip() or f"jev exited {done.returncode}")
    try:
        answers = json.loads(done.stdout)["answers"]
        return {name: float(answers[name]["noul"]) for name in QUESTIONS}
    except (ValueError, KeyError, TypeError) as error:
        raise Unreachable(f"unreadable answer: {error}") from None


def place(notification, book=None, asker=ask):
    """The band name for a notification, or None when it produces no item."""
    if source(notification) is None:
        return None
    described = describe(notification, contacts() if book is None else book)
    if described is None:
        return None
    state, work_contact = described
    try:
        answers = asker(state)
    except Unreachable:
        return "later"
    return band(answers, work_contact)
