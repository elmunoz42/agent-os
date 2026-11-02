#!/usr/bin/env python3
"""User story status report for Agent OS projects.

Reads agent-os/user-stories/US-*.md (and agent-os/testing.yml for the level),
prints a short summary, and writes a static HTML page:
agent-os/user-stories/report.html. Python 3.8+, standard library only.

Usage:
  python3 stories_report.py [project_dir] [--set demo|production] [--out FILE] [--quiet]
"""
import argparse
import datetime as dt
import html
import os
import re
import sys

STATUSES = ["failing", "ready", "draft", "verified"]  # display order: needs attention first


def parse_list(value):
    value = value.strip()
    if value.startswith("[") and value.endswith("]"):
        return [v.strip().strip("'\"") for v in value[1:-1].split(",") if v.strip()]
    return [value.strip("'\"")] if value else []


def parse_frontmatter(text):
    """Minimal parser for the story frontmatter format (flat keys, inline lists, one nested map)."""
    if not text.startswith("---"):
        return {}, text
    end = text.find("\n---", 3)
    if end == -1:
        return {}, text
    data, parent, last_key = {}, None, None
    for raw in text[3:end].splitlines():
        line = raw.split(" #", 1)[0].rstrip()
        if not line.strip():
            continue
        m = re.match(r"^(\s*)-\s+(.*)$", line)
        if m and last_key:  # block list item
            target = data[parent] if parent and isinstance(data.get(parent), dict) else data
            if not isinstance(target.get(last_key), list):
                target[last_key] = []
            target[last_key].append(m.group(2).strip().strip("'\""))
            continue
        m = re.match(r"^(\s*)([A-Za-z_][\w-]*):\s*(.*)$", line)
        if not m:
            continue
        indent, key, value = len(m.group(1)), m.group(2), m.group(3)
        if indent == 0:
            parent = None
            if value == "":
                data[key] = {}
                parent = key
            else:
                data[key] = parse_list(value) if value.startswith("[") else value.strip("'\"")
            last_key = key
        elif parent:
            data[parent][key] = parse_list(value) if value.startswith("[") else value.strip("'\"")
            last_key = key
    return data, text[end + 4:]


def parse_acs(body):
    acs = []
    for line in body.splitlines():
        m = re.match(r"^\s*-\s+AC(\d+)\s*(\(([^)]*)\))?\s*:", line)
        if m:
            tags = [t.strip() for t in (m.group(3) or "").split(",") if t.strip()]
            acs.append({"n": int(m.group(1)), "edge": "edge" in tags, "unit": "unit" in tags})
    return acs


def read_level(project):
    path = os.path.join(project, "agent-os", "testing.yml")
    try:
        for line in open(path, encoding="utf-8"):
            m = re.match(r"^level:\s*([A-Za-z]*)", line)
            if m:
                return m.group(1) or "not set"
    except OSError:
        pass
    return "not set"


def latest_run(stories_dir):
    runs = os.path.join(stories_dir, "_runs")
    try:
        names = sorted(d for d in os.listdir(runs) if os.path.isfile(os.path.join(runs, d, "report.md")))
    except OSError:
        return None
    return names[-1] if names else None


def load_stories(project):
    sdir = os.path.join(project, "agent-os", "user-stories")
    stories = []
    if not os.path.isdir(sdir):
        return sdir, stories
    for name in sorted(os.listdir(sdir)):
        if not re.match(r"^US-\d+.*\.md$", name):
            continue
        text = open(os.path.join(sdir, name), encoding="utf-8").read()
        fm, body = parse_frontmatter(text)
        acs = parse_acs(body)
        tests = fm.get("tests") if isinstance(fm.get("tests"), dict) else {}
        test_files = [t for k in ("e2e", "unit") for t in (tests.get(k) or []) if isinstance(t, str)]
        sets = fm.get("sets") or ["demo", "production"]
        stories.append({
            "file": name,
            "id": fm.get("id") or name.split("-", 2)[0] + "-" + name.split("-", 2)[1],
            "title": fm.get("title") or name,
            "status": (fm.get("status") or "draft").lower(),
            "level": fm.get("verified_level") or "",
            "sets": sets if isinstance(sets, list) else parse_list(sets),
            "priority": fm.get("priority") or "",
            "source": fm.get("source") or "",
            "last": fm.get("last_verified") or "",
            "acs": acs,
            "tests": test_files,
            "missing": [t for t in test_files if not os.path.exists(os.path.join(project, t))],
        })
    return sdir, stories


def summarize(stories):
    counts = {s: 0 for s in STATUSES}
    for st in stories:
        counts[st["status"]] = counts.get(st["status"], 0) + 1
    return counts


CSS = """
:root{--bg:#fff;--fg:#1d2329;--muted:#66717e;--line:#e3e7eb;--card:#f6f8fa;
--verified:#13795b;--failing:#c4312b;--ready:#9a6700;--draft:#66717e;--chip:#eef1f4}
@media (prefers-color-scheme:dark){:root{--bg:#0f1317;--fg:#e6eaee;--muted:#8d98a4;--line:#26303a;--card:#161c22;
--verified:#3fca8f;--failing:#f2706b;--ready:#e3b341;--draft:#8d98a4;--chip:#1f2730}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);
font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Inter,Roboto,sans-serif}
main{max-width:1100px;margin:0 auto;padding:32px 20px 60px}
h1{font-size:24px;margin:0 0 4px}.meta{color:var(--muted);font-size:13px;margin-bottom:24px}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin-bottom:28px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px}
.card b{display:block;font-size:26px;line-height:1.1}.card span{color:var(--muted);font-size:13px}
table{width:100%;border-collapse:collapse;font-size:14px}
th{text-align:left;color:var(--muted);font-weight:600;font-size:12px;text-transform:uppercase;letter-spacing:.04em;
border-bottom:1px solid var(--line);padding:8px 10px}
td{border-bottom:1px solid var(--line);padding:10px;vertical-align:top}
td.id{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;white-space:nowrap}
a{color:inherit}.badge{display:inline-block;padding:2px 9px;border-radius:999px;font-size:12px;font-weight:600;
border:1px solid currentColor}
.verified{color:var(--verified)}.failing{color:var(--failing)}.ready{color:var(--ready)}.draft{color:var(--draft)}
.chip{display:inline-block;background:var(--chip);border-radius:6px;padding:1px 7px;font-size:12px;margin:0 4px 2px 0}
.small{color:var(--muted);font-size:12px}.warn{color:var(--failing);font-size:12px}
@media (max-width:720px){.hide-sm{display:none}}
"""


def render_html(project, stories, level, run, set_filter):
    counts = summarize(stories)
    total = len(stories)
    acs = sum(len(s["acs"]) for s in stories)
    edge = sum(1 for s in stories for a in s["acs"] if a["edge"])
    e = html.escape
    name = os.path.basename(os.path.abspath(project))
    now = dt.datetime.now().strftime("%Y-%m-%d %H:%M")
    filt = " · showing set: %s" % e(set_filter) if set_filter else ""
    run_html = ('Latest run: <a href="_runs/%s/report.md">%s</a>' % (e(run), e(run))) if run else "No verification runs yet"
    cards = "".join(
        '<div class="card"><b class="%s">%d</b><span>%s</span></div>' % (st, counts.get(st, 0), st)
        for st in ["verified", "failing", "ready", "draft"])
    cards = '<div class="card"><b>%d</b><span>stories</span></div>' % total + cards + \
        '<div class="card"><b>%d</b><span>acceptance criteria, %d edge</span></div>' % (acs, edge)
    order = {s: i for i, s in enumerate(STATUSES)}
    rows = []
    for s in sorted(stories, key=lambda x: (order.get(x["status"], 9), x["id"])):
        n_edge = sum(1 for a in s["acs"] if a["edge"])
        n_unit = sum(1 for a in s["acs"] if a["unit"])
        ac_txt = "%d" % len(s["acs"]) + (" (%d edge, %d unit)" % (n_edge, n_unit) if (n_edge or n_unit) else "")
        lvl = ('<div class="small">at %s level</div>' % e(s["level"])) if s["status"] == "verified" and s["level"] else ""
        missing = "".join('<div class="warn">missing: %s</div>' % e(m) for m in s["missing"])
        tests = ('%d file%s' % (len(s["tests"]), "" if len(s["tests"]) == 1 else "s")) if s["tests"] else '<span class="small">none</span>'
        rows.append(
            "<tr><td class='id'><a href=\"%s\">%s</a></td><td>%s<div class='small'>%s</div></td>"
            "<td><span class='badge %s'>%s</span>%s</td><td>%s</td><td class='hide-sm'>%s</td>"
            "<td class='hide-sm'>%s%s</td><td class='hide-sm small'>%s</td></tr>" % (
                e(s["file"]), e(s["id"]), e(s["title"]), e(s["source"]),
                e(s["status"]), e(s["status"]), lvl,
                "".join('<span class="chip">%s</span>' % e(x) for x in s["sets"]),
                e(ac_txt), tests, missing, e(s["last"] or "never")))
    table = ("<table><thead><tr><th>ID</th><th>Story</th><th>Status</th><th>Sets</th>"
             "<th class='hide-sm'>ACs</th><th class='hide-sm'>Tests</th><th class='hide-sm'>Last verified</th></tr></thead>"
             "<tbody>%s</tbody></table>" % "".join(rows)) if rows else "<p>No user stories yet. Run /write-user-stories to add some.</p>"
    return ("<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
            "<title>User stories · %s</title><style>%s</style></head><body><main>"
            "<h1>User stories · %s</h1><div class='meta'>Testing level: <b>%s</b> · Generated %s · %s%s</div>"
            "<div class='cards'>%s</div>%s</main></body></html>\n") % (
        e(name), CSS, e(name), e(level), now, run_html, filt, cards, table)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Write agent-os/user-stories/report.html and print a summary.")
    ap.add_argument("project", nargs="?", default=".", help="project folder (default: current folder)")
    ap.add_argument("--set", choices=["demo", "production"], help="only stories in this set")
    ap.add_argument("--out", help="output HTML path (default: agent-os/user-stories/report.html)")
    ap.add_argument("--quiet", action="store_true", help="no terminal summary")
    a = ap.parse_args(argv)

    project = os.path.abspath(a.project)
    if not os.path.isdir(os.path.join(project, "agent-os")):
        print("No agent-os/ folder in %s" % project, file=sys.stderr)
        return 1
    sdir, stories = load_stories(project)
    if a.set:
        stories = [s for s in stories if a.set in s["sets"]]
    level = read_level(project)
    run = latest_run(sdir)
    os.makedirs(sdir, exist_ok=True)
    out = os.path.abspath(a.out) if a.out else os.path.join(sdir, "report.html")
    with open(out, "w", encoding="utf-8") as f:
        f.write(render_html(project, stories, level, run, a.set))

    if not a.quiet:
        c = summarize(stories)
        print("User stories: %d  |  verified %d  failing %d  ready %d  draft %d  |  level: %s" % (
            len(stories), c.get("verified", 0), c.get("failing", 0), c.get("ready", 0), c.get("draft", 0), level))
        for s in stories:
            if s["status"] == "failing" or s["missing"]:
                why = "failing" if s["status"] == "failing" else "missing test files"
                print("  %s  %s  (%s)" % (s["id"], s["title"], why))
        rel = os.path.relpath(out)
        print("Report: %s" % (out if rel.startswith("..") else rel))
    return 0


if __name__ == "__main__":
    sys.exit(main())
