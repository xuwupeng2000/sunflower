#!/usr/bin/env python3
"""把散在各处的翻译收进一张表：locale/翻译总表.html。

只读不写源文件。改完翻译重跑一次：python3 locale/collect_translations.py
"""
import csv
import html
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "locale" / "翻译总表.html"
COLUMNS = [
    ("zh", "简体中文"), ("en", "English"), ("zh_TW", "繁體中文"),
    ("ja", "日本語"), ("ko", "한국어"), ("de", "Deutsch"), ("fr", "Français"),
    ("it", "Italiano"), ("es", "Español"), ("ru", "Русский"),
]
LPROJ = {"zh-Hans": "zh", "zh-Hant": "zh_TW"}
QUOTED = r'"((?:[^"\\]|\\.)*)"'


def unescape(text: str) -> str:
    return text.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def used_in(key: str, files: dict[str, str]) -> str:
    needles = {'"' + key + '"', '"' + key.replace("\n", "\\n") + '"'}
    hits = [name for name, text in files.items() if any(needle in text for needle in needles)]
    return "、".join(hits) if hits else "（没找到用处，可能是旧词条）"


def godot_rows() -> list[dict]:
    sources = {}
    for path in sorted(ROOT.rglob("*")):
        parts = path.relative_to(ROOT).parts
        if parts[0] in ("addons", "tests", ".godot", "ios", "docs") or path.suffix not in (".tscn", ".gd", ".tres"):
            continue
        sources[path.name] = path.read_text(encoding="utf-8")
    rows = []
    with open(ROOT / "locale" / "ui.csv", encoding="utf-8") as handle:
        for record in csv.DictReader(handle):
            key = record.pop("keys")
            row = {"zh": key, **record}
            row["where"] = used_in(key, sources)
            rows.append(row)
    return rows


def swift_rows() -> list[dict]:
    files = {p.name: p.read_text(encoding="utf-8") for p in sorted((ROOT / "ios").rglob("*.swift"))
             if "xcframework" not in str(p)}
    more: dict[str, dict] = {}
    shared = files.get("SunflowerShared.swift", "")
    table = shared.split("static let more", 1)[-1]
    for line in table.splitlines():
        found = re.match(r"\s*" + QUOTED + r":\s*\[(.*)\],?\s*$", line)
        if found:
            pairs = re.findall(r'"(\w+)":\s*' + QUOTED, found.group(2))
            more[unescape(found.group(1))] = {lang: unescape(text) for lang, text in pairs}
    pattern = re.compile(r"Copy\.text\(\s*" + QUOTED + r"\s*,\s*" + QUOTED + r"(?:\s*,\s*hant:\s*" + QUOTED + r")?")
    rows: dict[str, dict] = {}
    for name, text in files.items():
        for zh, en, hant in pattern.findall(text):
            en = unescape(en)
            row = rows.setdefault(en, {"zh": unescape(zh), "en": en, "zh_TW": unescape(hant or zh), "where": set()})
            row["where"].add(name)
    for en, row in rows.items():
        row.update(more.get(en, {}))
        row["where"] = "、".join(sorted(row["where"]))
    for en in more:
        if en not in rows:
            rows[en] = {"en": en, **more[en], "where": "（Swift 里没有用到）"}
    return list(rows.values())


def strings_rows(folder: Path, where: str) -> list[dict]:
    rows: dict[str, dict] = {}
    for lproj in sorted(folder.glob("*.lproj")):
        lang = LPROJ.get(lproj.stem, lproj.stem)
        for path in lproj.glob("*.strings"):
            for line in path.read_text(encoding="utf-8").splitlines():
                found = re.match(r'\s*"?([^"=]+?)"?\s*=\s*' + QUOTED + r"\s*;", line)
                if found:
                    key = found.group(1).strip()
                    rows.setdefault(key, {"key": key, "where": where})[lang] = unescape(found.group(2))
    return list(rows.values())


def section(title: str, note: str, rows: list[dict], show_key: bool = False) -> str:
    head = "<th>用在哪</th>" + ("<th>键</th>" if show_key else "")
    head += "".join(f"<th>{html.escape(label)}</th>" for _, label in COLUMNS)
    body = []
    for index, row in enumerate(rows, 1):
        cells = [f'<td class="where">{index}. {html.escape(row.get("where", ""))}</td>']
        if show_key:
            cells.append(f'<td class="where">{html.escape(row.get("key", ""))}</td>')
        for lang, _ in COLUMNS:
            text = row.get(lang, "")
            if text:
                cells.append(f"<td>{html.escape(text)}</td>")
            else:
                cells.append('<td class="missing">（同英文）</td>')
        body.append("<tr>" + "".join(cells) + "</tr>")
    return (f"<h2>{html.escape(title)}（{len(rows)} 条）</h2><p>{html.escape(note)}</p>"
            f"<table><thead><tr>{head}</tr></thead><tbody>{''.join(body)}</tbody></table>")


def main() -> None:
    parts = [
        section("App 界面", "源文件 locale/ui.csv。%s、%d、{m} 这类是占位符，会换成数字或文字，数量要和中文一致。",
                godot_rows()),
        section("锁屏闹钟、灵动岛、小组件", "源文件 ios/shared/SunflowerShared.swift（Copy.more 表）和各 Swift 文件里的 Copy.text。",
                swift_rows()),
        section("手机「设置」里的语言选项", "源文件 ios/Settings.bundle/*.lproj/Root.strings。",
                strings_rows(ROOT / "ios" / "Settings.bundle", "设置页"), show_key=True),
        section("主屏幕上的名字、闹钟权限提示", "源文件 ios/info_strings/*.lproj/InfoPlist.strings。",
                strings_rows(ROOT / "ios" / "info_strings", "系统"), show_key=True),
    ]
    page = f"""<!doctype html><html lang="zh"><meta charset="utf-8"><title>翻译总表</title>
<style>
body{{font-family:-apple-system,"PingFang SC",sans-serif;margin:16px;font-size:13px}}
table{{border-collapse:collapse;margin-bottom:32px}}
th,td{{border:1px solid #ddd;padding:4px 6px;vertical-align:top;white-space:pre-wrap;max-width:220px}}
th{{background:#f3efe6;position:sticky;top:0}}
td.where{{color:#777;font-size:11px;max-width:140px}}
td.missing{{background:#fde2e2;color:#b33}}
tr:hover td{{background:#fffbe8}}
</style>
<h1>翻译总表</h1>
<p>由 locale/collect_translations.py 生成，不要手改这张表；改源文件后重跑脚本。红格表示这种语言没有单独翻译，会显示英文。</p>
{''.join(parts)}
</html>"""
    OUT.write_text(page, encoding="utf-8")
    print(OUT)


if __name__ == "__main__":
    main()
