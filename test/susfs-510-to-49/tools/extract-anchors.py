#!/usr/bin/env python3
"""
extract-anchors.py — build the 5.10->4.9 hunk anchor map from the frozen
4.9 reference (supervised). One-time per upstream sync: pair each 5.10
hunk with the 4.9 hunk that carries the same content, then record the
4.9 anchor (host function + insertion point class).

The map is the durable 4.9 structural knowledge; the frozen patch only
seeds it. When upstream moves, re-run against the updated 5.10 segment:
content-identical hunks keep their anchor; changed hunks surface for a
manual anchor review instead of being silently misplaced.

Usage:
  extract-anchors.py <upstream-5.10-segment.diff> <frozen-4.9-segment.diff>
      <file> [--out anchors-4.9.json]
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
            cur = {'hdr': ln.rstrip('\n'), 'ctx': [], 'adds': [], 'dels': []}
        elif cur is not None:
            if ln.startswith(' '):
                cur['ctx'].append(ln[1:].rstrip('\n'))
            elif ln.startswith('+') and not ln.startswith('+++'):
                cur['adds'].append(ln[1:].rstrip('\n'))
            elif ln.startswith('-') and not ln.startswith('---'):
                cur['dels'].append(ln[1:].rstrip('\n'))
    if cur:
        out.append(cur)
    return out


def content_sig(adds):
    """order-insensitive signature: sorted distinctive content lines.
    Preprocessor-only blocks (include guards) sign by their content."""
    sem = [l for l in adds if l.strip() and not l.startswith('#')]
    if sem:
        return sorted(sem)
    return sorted(l for l in adds if l.strip())


def host_fn_of_hunk(h):
    """host function hint: prefer a DEFINITION line in the context
    (types + name + '(' ... no ';', not an assignment/call); fall back
    to the hunk header tail. Calls like 'x = foo(...)' are skipped."""
    for ln in reversed(h['ctx']):
        s = ln.strip()
        if not s or s.startswith(('#', '//', 'extern', 'EXPORT')):
            continue
        if s in ('{', '}') or re.match(r'^\t?(?:if|for|while|return|'
                                       r'switch|goto)\b', s):
            continue
        if '=' in s.split('(')[0]:
            continue  # assignment to a call result
        m = re.match(r'^(?:[A-Za-z_][\w\s\*]*\s+)?([a-z_][a-z0-9_]*)\s*\(', s)
        if m and ';' not in s.split('(')[-1]:
            return m.group(1)
    tail = h['hdr'].split('@@')[-1].strip()
    m = re.match(r'^(?:[A-Za-z_][\w\s\*]*\s+)?([a-z_][a-z0-9_]*)\s*\(', tail)
    return m.group(1) if m else None


def classify(adds):
    txt = '\n'.join(adds)
    if any('include <' in a for a in adds):
        return 'include'
    if any(a.lstrip().startswith('extern') for a in adds):
        return 'extern'
    return 'body'


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return 1
    up_path, ref_path, fname = sys.argv[1], sys.argv[2], sys.argv[3]
    out_path = None
    if '--out' in sys.argv:
        out_path = sys.argv[sys.argv.index('--out') + 1]
    up_hunks = parse_hunks(open(up_path).read())
    ref_hunks = parse_hunks(open(ref_path).read())
    ref_sigs = [content_sig(h['adds']) for h in ref_hunks]

    entries = []
    used_ref = set()
    for ui, uh in enumerate(up_hunks):
        usig = content_sig(uh['adds'])
        # pick best unused ref hunk by content overlap
        best_j, best_score = -1, -1
        for rj, rsig in enumerate(ref_sigs):
            if rj in used_ref:
                continue
            inter = len(set(usig) & set(rsig))
            union = len(set(usig) | set(rsig)) or 1
            score = inter / union
            if score > best_score:
                best_j, best_score = rj, score
        if best_j >= 0 and best_score >= 0.5:
            used_ref.add(best_j)
            entries.append({
                'up_hunk': ui,
                'ref_hunk': best_j,
                'score': round(best_score, 3),
                'up_host': host_fn_of_hunk(uh),
                'ref_host': host_fn_of_hunk(ref_hunks[best_j]),
                'kind': classify(uh['adds']),
            })
        else:
            entries.append({
                'up_hunk': ui, 'ref_hunk': None, 'score': round(best_score, 3),
                'up_host': host_fn_of_hunk(uh), 'ref_host': None,
                'kind': classify(uh['adds']),
            })
    doc = {
        'file': fname,
        'note': '5.10 hunk -> 4.9 hunk anchor map (content-supervised)',
        'entries': entries,
    }
    if out_path:
        json.dump(doc, open(out_path, 'w'), indent=1)
        print(f'wrote {out_path} ({len(entries)} entries, '
              f'{sum(1 for e in entries if e["ref_hunk"] is not None)} paired)')
    else:
        print(json.dumps(doc, indent=1))
    return 0


if __name__ == '__main__':
    sys.exit(main())
