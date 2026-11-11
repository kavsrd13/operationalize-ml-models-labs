"""Build offline HTML instruction pages and one complete course index.

Only Python's standard library is required. Run from anywhere with
`python scripts/build_instructions.py`.
"""

from __future__ import annotations

import html
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LABS = sorted(p for p in ROOT.iterdir() if p.is_dir() and re.match(r"^\d\d-", p.name))


def inline(value: str, link_prefix: str = "") -> str:
    value = html.escape(value)
    value = re.sub(r"`([^`]+)`", r"<code>\1</code>", value)
    value = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", value)
    def link(match: re.Match[str]) -> str:
        label, target = match.groups()
        if not (target.startswith(("https://", "http://", "../", "./"))):
            return match.group(0)
        href = target if target.startswith(("https://", "http://")) else link_prefix + target
        return f'<a href="{html.escape(href, quote=True)}">{label}</a>'

    value = re.sub(r"\[([^]]+)\]\(([^)]+)\)", link, value)
    return value


def render(markdown: str, link_prefix: str = "") -> str:
    out: list[str] = []
    lines = markdown.splitlines()
    paragraph: list[str] = []
    list_kind: str | None = None
    code: list[str] | None = None
    table: list[list[str]] = []

    def flush_paragraph() -> None:
        if paragraph:
            out.append(f"<p>{inline(' '.join(s.strip() for s in paragraph), link_prefix)}</p>")
            paragraph.clear()

    def close_list() -> None:
        nonlocal list_kind
        if list_kind:
            out.append(f"</{list_kind}>")
            list_kind = None

    def flush_table() -> None:
        if table:
            out.append("<table><thead><tr>" + "".join(f"<th>{inline(c, link_prefix)}</th>" for c in table[0]) + "</tr></thead><tbody>")
            for row in table[1:]:
                out.append("<tr>" + "".join(f"<td>{inline(c, link_prefix)}</td>" for c in row) + "</tr>")
            out.append("</tbody></table>")
            table.clear()

    for line in lines + [""]:
        stripped = line.strip()
        if stripped.startswith("```"):
            flush_paragraph()
            flush_table()
            close_list()
            if code is None:
                code = []
            else:
                out.append("<pre><code>" + html.escape("\n".join(code)) + "</code></pre>")
                code = None
            continue
        if code is not None:
            code.append(line)
            continue
        if not stripped:
            flush_paragraph()
            flush_table()
            close_list()
            continue
        if re.match(r"^\|\s*[-:]", stripped):
            continue
        if stripped.startswith("|") and stripped.endswith("|"):
            flush_paragraph()
            close_list()
            table.append([part.strip() for part in stripped.strip("|").split("|")])
            continue
        flush_table()
        heading = re.match(r"^(#{1,3})\s+(.+)$", stripped)
        if heading:
            flush_paragraph()
            close_list()
            level = len(heading.group(1))
            out.append(f"<h{level}>{inline(heading.group(2), link_prefix)}</h{level}>")
            continue
        item = re.match(r"^(\d+\.\s+|[-*]\s+)(.+)$", stripped)
        if item:
            flush_paragraph()
            kind = "ol" if item.group(1)[0].isdigit() else "ul"
            if list_kind != kind:
                close_list()
                start = f' start="{int(item.group(1).split(".")[0])}"' if kind == "ol" else ""
                out.append(f"<{kind}{start}>")
                list_kind = kind
            out.append(f"<li>{inline(item.group(2), link_prefix)}</li>")
            continue
        if list_kind and line.startswith(" ") and out and out[-1].startswith("<li>"):
            out[-1] = out[-1][:-5] + " " + inline(stripped, link_prefix) + "</li>"
        else:
            close_list()
            paragraph.append(stripped)
    return "\n".join(out)


def page(title: str, body: str, stylesheet: str, nav: str) -> str:
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)} | Operationalize Machine Learning Models</title>
<link rel="stylesheet" href="{stylesheet}"></head>
<body><header><a class="brand" href="{nav}">Operationalize Machine Learning Models</a><span>Student lab guide</span></header>
<main>{body}</main><footer>Run cloud commands in your own Azure ML workspace. See each lab's validation status.</footer></body></html>
"""


def main() -> None:
    cards = []
    sections = []
    for lab in LABS:
        source = lab / "Instruction" / "README.md"
        if not source.is_file():
            raise SystemExit(f"Missing instruction: {source}")
        markdown = source.read_text(encoding="utf-8")
        title = markdown.splitlines()[0].removeprefix("# ")
        body = render(markdown)
        (lab / "Instruction" / "index.html").write_text(
            page(title, f'<nav><a href="../../index.html">← All exercises</a></nav><article>{body}</article>', "../../assets/site.css", "../../index.html"),
            encoding="utf-8",
            newline="\n",
        )
        cards.append(f'<a class="card" href="{lab.name}/Instruction/index.html"><small>{lab.name[:2]}</small><strong>{html.escape(title)}</strong><span>Open this exercise →</span></a>')
        root_body = render(markdown, f"{lab.name}/Instruction/")
        sections.append(f'<section id="lab-{lab.name[:2]}"><div class="section-nav"><a href="#top">↑ Back to top</a> · <a href="{lab.name}/Instruction/index.html">Separate page</a></div>{root_body}</section>')
    body = '<div id="top" class="intro"><p class="eyebrow">SELF-PACED COURSE</p><h1>Operationalize Machine Learning Models</h1><p>All student instructions in one page. Each exercise can start from a fresh clone; reuse the same Azure workspace and generic compute name when taking several labs.</p></div>'
    body += '<div class="cards">' + "\n".join(cards) + '</div><div class="all-labs">' + "\n".join(sections) + '</div>'
    (ROOT / "index.html").write_text(page("All exercises", body, "assets/site.css", "index.html"), encoding="utf-8", newline="\n")
    print(f"Built {len(LABS)} exercise pages and one complete index")


if __name__ == "__main__":
    main()
