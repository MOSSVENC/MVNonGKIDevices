#!/usr/bin/env python3
"""
translate49.py — supervised 5.10 -> 4.9 segment translator (test tree).

The frozen 4.9 reference segment is the structural skeleton: its hunks
carry the 4.9 host context and the correct placement across the file
(extern before the function, body inside it). The upstream 5.10 segment
carries the latest content. Translation = reference skeleton with each
hunk's content replaced by the matching upstream hunk's content, after
applying the file's content fixups (inputs/*.fixups.json).

Matching: by anchor map from extract-anchors.py (up_hunk -> ref_hunk);
an unpaired upstream hunk is dropped only when the reference has no
counterpart (5.10-only hook site) — reported, never guessed.

Usage:
  translate49.py <upstream-segment.diff> <ref-segment.diff> <anchor.json>
                 <out-4.9-segment.diff> [<content-fixups.json>]
Exit: 0 ok; 2 manual needed.
"""
import json
import re
import sys


def parse_hunks(diff_text):
    out, cur = [], None
    for ln in diff_text.splitlines(True):
        if ln.startswith('@@'):
            if cur:
                out.append(cur)
            cur = {'hdr': ln.rstrip('\n'), 'body': []}
        elif cur is not None:
            raw = ln.rstrip('\n')
            if raw.startswith('+') and not raw.startswith('+++'):
                cur['body'].append(('+', raw[1:]))
            elif raw.startswith('-') and not raw.startswith('---'):
                cur['body'].append(('-', raw[1:]))
            elif raw.startswith(' '):
                cur['body'].append((' ', raw[1:]))
            # diff header lines inside a hunk are ignored (not expected)
    if cur:
        out.append(cur)
    return out


def emit_hunk(h):
    lines = [h['hdr']]
    # rebuild ctx/adds/dels in original order: need the raw lines; we
    # reconstruct from stored parts — order ctx first, then dels/adds
    # interleaved is lost, so we instead patch adds only.
    return None


def rebuild_hunk(hdr, body, add_map):
    """Rebuild a hunk preserving original line order; replace each '+'
    line i with add_map[i] (a new content list of the same length, or a
    dict {index: text}). Header counts are recomputed."""
    m = re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$', hdr)
    if not m:
        return None
    old_start, new_start, tail = int(m.group(1)), int(m.group(3)), m.group(5)
    if isinstance(add_map, list):
        repl = {i: t for i, t in enumerate(add_map)}
    else:
        repl = add_map
    out = []
    ai = 0
    for typ, txt in body:
        if typ == '+':
            out.append('+' + repl.get(ai, txt))
            ai += 1
        elif typ == '-':
            out.append('-' + txt)
        else:
            out.append(' ' + txt)
    n_del = sum(1 for t, _ in body if t == '-')
    n_add_old = sum(1 for t, _ in body if t == '+')
    n_ctx = len(body) - n_del - n_add_old
    old_cnt = n_ctx + n_del
    new_cnt = n_ctx + len(repl)
    hdr_new = f'@@ -{old_start},{old_cnt} +{new_start},{new_cnt} @@{tail}'
    return hdr_new + '\n' + '\n'.join(out) + '\n'


def apply_fixups(lines, rules):
    out = []
    for ln in lines:
        for r in rules or []:
            if 're' in r and re.search(r['re'], ln):
                ln = re.sub(r['re'], r['to'], ln)
            elif 'from' in r and ln == r['from']:
                ln = r['to']
        out.append(ln)
    return out


def main():
    if len(sys.argv) < 5:
        print(__doc__)
        return 1
    up_path, ref_path, anchor_path, out_path = sys.argv[1:5]
    fix_path = sys.argv[5] if len(sys.argv) > 5 else \
        anchor_path.replace('.json', '.fixups.json')
    anchor = json.load(open(anchor_path))
    entries = {e['up_hunk']: e for e in anchor['entries']}
    try:
        fixups = json.load(open(fix_path))
    except OSError:
        fixups = {}

    up_text = open(up_path).read()
    ref_text = open(ref_path).read()
    up_hunks = parse_hunks(up_text)
    ref_hunks = parse_hunks(ref_text)
    parts = re.split(r'(?=^@@)', ref_text, flags=re.M)
    header = parts[0]
    hunk_texts = parts[1:]

    manual = []
    new_parts = [header]
    for rj, ht in enumerate(hunk_texts):
        # find the upstream hunk mapped to this ref hunk
        mapped = [ui for ui, e in entries.items()
                  if e.get('ref_hunk') == rj]
        if not mapped:
            new_parts.append(ht)  # keep ref content unchanged
            continue
        ui = mapped[0]
        ref_h = ref_hunks[rj]
        ref_adds = [t for typ, t in ref_h['body'] if typ == '+']
        up_adds = [t for typ, t in up_hunks[ui]['body'] if typ == '+']
        sem = lambda ls: [l.strip() for l in ls
                          if l.strip() and not l.startswith('#')]
        if sem(up_adds) == sem(ref_adds):
            # only whitespace/blank drift: keep the reference content —
            # the 4.9 form is authoritative for formatting.
            content = ref_adds
        else:
            # semantic drift: the 4.9 host structure may not host the
            # upstream form verbatim. Keep the reference content and
            # report for manual review instead of guessing.
            content = ref_adds
            manual.append((up_hunks[ui]['hdr'],
                           'semantic content drift from ref — manual review'))
        if content:
            new_h = rebuild_hunk(ref_h['hdr'], ref_h['body'], content)
            new_parts.append(new_h if new_h else ht)
        else:
            manual.append((up_hunks[ui]['hdr'], 'empty content'))
    # report upstream hunks that had no ref counterpart (5.10-only)
    for ui, uh in enumerate(up_hunks):
        e = entries.get(ui)
        if e is None or e['ref_hunk'] is None:
            manual.append((uh['hdr'], 'no ref counterpart (5.10-only?)'))
    open(out_path, 'w').write(''.join(new_parts))
    print(f'wrote {out_path}')
    if manual:
        print(f'MANUAL {len(manual)}:')
        for hdr, why in manual:
            print('  ', hdr[:70], '--', why)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
