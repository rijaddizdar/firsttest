#!/usr/bin/env python3
"""Generate docs/world-<n>-lesson-scripts.md for every written world.

The scripts doc has to be read as WRITING, not as JSON, and it must never
drift from what the app actually plays — so it is generated from the same
files the app loads. Re-run after editing any lesson:

    python3 docs/tools/generate_lesson_scripts.py
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONTENT = os.path.join(ROOT, "App", "Content")

NAME = "Mia"  # the demo child, so {name} reads as a real line


def fill(text):
    return (text or "").replace("{name}", NAME)


def words(sentence):
    return len([w for w in re.split(r"\s+", sentence.strip()) if w])


def sentences(text):
    return [s for s in re.split(r"(?<=[.!?])\s+", fill(text).strip()) if s]


LONGEST = []  # (words, lesson, sentence) for the tone check at the end


def note(lesson_id, text):
    for s in sentences(text):
        LONGEST.append((words(s), lesson_id, s))


def screen_md(lesson_id, n, screen):
    t = screen["type"]
    out = []
    head = f"**{n}. "
    if t == "hello":
        out.append(head + 'Hello.**')
        out.append(f'Penny ({screen.get("pose", "wave")}): *"{fill(screen["penny"])}"*')
        out.append(f'Button: `{screen.get("continueLabel", "Let\'s go!")}`')
        note(lesson_id, screen["penny"])
    elif t == "learn":
        out.append(head + f'Learn — {fill(screen["title"])}.**')
        for c in screen["cards"]:
            out.append(f'- **{c["badge"]}** ({c["icon"]}, {c["tint"]}) — {fill(c["caption"])}')
            note(lesson_id, c["caption"])
        if screen.get("penny"):
            out.append(f'Penny: *"{fill(screen["penny"])}"*')
            note(lesson_id, screen["penny"])
        out.append(f'Button: `{screen.get("continueLabel", "I\'m ready")}`')
    elif t == "tapToChoose":
        out.append(head + 'Tap to choose.**')
        out.append(f'> {fill(screen["prompt"])}')
        out.append(f'Penny: *"{fill(screen["pennyHint"])}"*')
        for c in screen["choices"]:
            mark = " ✅" if c.get("correct") else ""
            out.append(f'- **{c["label"]}** ({c["icon"]}){mark}')
        out.append(f'Right → *"{fill(screen["rightMessage"])}"*')
        out.append(f'Try again → *"{fill(screen["wrongMessage"])}"*')
        if screen.get("retryIntro"):
            out.append(f'Comes back later → *"{fill(screen["retryIntro"])}"*')
        for k in ("prompt", "pennyHint", "rightMessage", "wrongMessage", "retryIntro"):
            note(lesson_id, screen.get(k))
    elif t == "sortIt":
        out.append(head + 'Sort it.**')
        out.append(f'> {fill(screen["prompt"])}')
        out.append(f'Penny: *"{fill(screen["pennyHint"])}"*')
        for g in screen["groups"]:
            items = ", ".join(i["label"] for i in screen["items"] if i["groupID"] == g["id"])
            out.append(f'- Basket **{g["title"]}** ({g.get("icon")}, {g["tint"]}) ← {items}')
        out.append(f'Right drop → *"{fill(screen["rightMessage"])}"*')
        out.append(f'Try again → *"{fill(screen["wrongMessage"])}"*')
        out.append(f'All sorted → *"{fill(screen["doneMessage"])}"*')
        if screen.get("retryIntro"):
            out.append(f'Comes back later → *"{fill(screen["retryIntro"])}"*')
        for k in ("prompt", "pennyHint", "rightMessage", "wrongMessage", "doneMessage", "retryIntro"):
            note(lesson_id, screen.get(k))
    elif t == "storyChoice":
        out.append(head + 'Story choice.**')
        out.append(f'Story ({screen.get("storyIcon")}): {fill(screen["story"])}')
        out.append(f'> {fill(screen["prompt"])}')
        out.append(f'Penny: *"{fill(screen["pennyHint"])}"*')
        for o in screen["options"]:
            mark = " ✅" if o.get("correct") else ""
            out.append(f'- **{o["label"]}** ({o["icon"]}){mark} → *{fill(o["outcome"])}*')
            note(lesson_id, o["outcome"])
        out.append(f'Right → *"{fill(screen["rightMessage"])}"*')
        out.append(f'Try again → *"{fill(screen["wrongMessage"])}"*')
        if screen.get("retryIntro"):
            out.append(f'Comes back later → *"{fill(screen["retryIntro"])}"*')
        for k in ("story", "prompt", "pennyHint", "rightMessage", "wrongMessage", "retryIntro"):
            note(lesson_id, screen.get(k))
    elif t == "countIt":
        out.append(head + 'Count it.**')
        out.append(f'> {fill(screen["prompt"])}')
        out.append(f'Penny: *"{fill(screen["pennyHint"])}"*')
        out.append(f'{screen["available"]} play coins in the pile · answer **{screen["target"]}** · '
                   f'jar: {screen.get("jarLabel")} ({screen.get("jarIcon", "jar")}) · '
                   f'button `{screen.get("checkLabel", "Check my jar")}`')
        out.append(f'Right → *"{fill(screen["rightMessage"])}"*')
        out.append(f'Try again → *"{fill(screen["wrongMessage"])}"*')
        if screen.get("retryIntro"):
            out.append(f'Comes back later → *"{fill(screen["retryIntro"])}"*')
        for k in ("prompt", "pennyHint", "rightMessage", "wrongMessage", "retryIntro"):
            note(lesson_id, screen.get(k))
    elif t == "yay":
        out.append(head + 'Yay!**')
        out.append(f'*"{fill(screen.get("title", "Lesson done, {name}!"))}"* — '
                   f'*{fill(screen.get("message", ""))}*')
        out.append("Stars, play coins and the coin streak.")
        note(lesson_id, screen.get("title"))
        note(lesson_id, screen.get("message"))
    return "\n\n".join(out)


def main():
    curriculum = json.load(open(os.path.join(CONTENT, "curriculum.json")))
    # One page per world that actually has lessons. Writing a new world adds a
    # page here with no change to this script.
    written = [(n, w) for n, w in enumerate(curriculum["worlds"], start=1)
               if any(lv["lessons"] for lv in w["levels"])]
    for number, world in written:
        build(number, world)


def build(number, world):
    global LONGEST
    LONGEST = []
    out = os.path.join(ROOT, "docs", f"world-{number}-lesson-scripts.md")

    md = []
    md.append(f'# World {number} lesson scripts — {world["title"]}')
    md.append("")
    md.append(f'Every word a child reads or hears in World {number}, screen by screen, so the '
              "lessons can be reviewed as **writing** rather than as JSON.")
    md.append("")
    md.append("- **Generated** from `App/Content/lessons/*.json` by "
              "`docs/tools/generate_lesson_scripts.py`. Edit the lesson files, then re-run it — "
              "never edit this page by hand.")
    md.append("- `{name}` is the child's own name. It is shown here as **Mia**.")
    md.append("- ✅ marks the right answer. Every wrong answer gets encouragement plus a hint, "
              "and comes back later in the lesson (README section 3).")
    md.append("- The name in brackets after a picture is its Fluent Emoji 3D icon in "
              "`Assets.xcassets/Icons`.")
    md.append("- Each level ends with a **level check**, which is built from that level's own "
              "questions rather than written here — see `App/Lessons/LevelCheck.swift`.")
    md.append("")

    # Contents
    md.append("## Contents")
    md.append("")
    for level in world["levels"]:
        md.append(f'- **Level {level["id"]} · {level["title"]}**')
        for lid in level["lessons"]:
            lesson = json.load(open(os.path.join(CONTENT, "lessons", lid + ".json")))
            md.append(f'  - [{lesson["title"]}](#{slug(lesson["title"], lid)}) — `{lid}`')
        md.append(f'  - Level check (built, not written)')
    md.append("")

    totals = {"lessons": 0, "screens": 0, "questions": 0}
    kinds = {}

    for level in world["levels"]:
        md.append("---")
        md.append("")
        md.append(f'## Level {level["id"]} · {level["title"]}')
        md.append("")
        md.append(f'*{level["kidSummary"]}*  ·  level icon `{level["icon"]}`')
        md.append("")
        for lid in level["lessons"]:
            lesson = json.load(open(os.path.join(CONTENT, "lessons", lid + ".json")))
            screens = lesson["screens"]
            qs = [s for s in screens
                  if s["type"] in ("tapToChoose", "sortIt", "storyChoice", "countIt")]
            totals["lessons"] += 1
            totals["screens"] += len(screens)
            totals["questions"] += len(qs)
            for s in screens:
                kinds[s["type"]] = kinds.get(s["type"], 0) + 1

            md.append(f'### {lesson["title"]}')
            md.append("")
            md.append(f'`{lid}` · {len(screens)} screens · {len(qs)} questions · '
                      f'about {lesson.get("estimatedMinutes", 3)} minutes · '
                      f'{lesson.get("coins", 10)} play coins')
            md.append("")
            for n, screen in enumerate(screens, start=1):
                md.append(screen_md(lid, n, screen))
                md.append("")

        md.append(f'### {level["title"]} Check')
        md.append("")
        md.append(f'`level-{level["id"]}-check` · built at runtime from the questions above: '
                  f'one from each lesson in turn, four in all, then a celebration. '
                  f'It cannot be failed — a missed question simply comes back until it is right. '
                  f'15 play coins.')
        md.append("")
        md.append(f'Penny opens it with: *"Nice work on {level["title"]}, Mia! '
                  f'Let\'s try a few again together."* and closes with '
                  f'*"Level finished, Mia!"* — *You tried every question until you got it. '
                  f'That\'s how learning works.*')
        md.append("")

    md.append("---")
    md.append("")
    md.append("## What this adds up to")
    md.append("")
    md.append(f'| | |')
    md.append(f'|---|---|')
    md.append(f'| Lessons | {totals["lessons"]} (5 per level) |')
    md.append(f'| Screens | {totals["screens"]} |')
    md.append(f'| Questions a child answers | {totals["questions"]} |')
    md.append(f'| Level checks | {len(world["levels"])}, built from the questions above |')
    md.append("")
    md.append("Screens by type:")
    md.append("")
    md.append("| Screen | Count |")
    md.append("|---|---|")
    for k in ("hello", "learn", "tapToChoose", "sortIt", "storyChoice", "countIt", "yay"):
        md.append(f'| {k} | {kinds.get(k, 0)} |')
    md.append("")

    LONGEST.sort(reverse=True)
    over = [x for x in LONGEST if x[0] > 12]
    md.append(f'**Sentence length (README section 7 rule 1: aim for 12 words or fewer).** '
              f'{len(LONGEST) - len(over)} of {len(LONGEST)} sentences are 12 words or fewer.')
    md.append("")
    if over:
        md.append("The longest lines, for a second opinion:")
        md.append("")
        md.append("| Words | Lesson | Line |")
        md.append("|---|---|---|")
        for w, lid, s in over[:12]:
            md.append(f'| {w} | `{lid}` | {s} |')
        md.append("")

    with open(out, "w") as f:
        f.write("\n".join(md).rstrip() + "\n")
    print(f"wrote {out}: {totals}")
    print(f"sentences over 12 words: {len(over)}")
    for w, lid, s in over[:20]:
        print(f"  {w:3d} {lid}: {s}")


def slug(title, lid):
    s = title.lower()
    s = re.sub(r"[^a-z0-9 -]", "", s)
    return s.replace(" ", "-")


if __name__ == "__main__":
    main()
