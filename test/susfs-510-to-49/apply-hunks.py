#!/usr/bin/env python3
"""
apply-hunks.py — apply a (mostly pure-insertion) unified-diff segment
for one file to the 4.9 target by relocating hunks.

Strategy: every hunk is decomposed into
  - context lines (space prefix)
  - added lines (+)
  - deleted lines (-)

For pure-insertion hunks (no '-' lines), we locate the *last* context
line inside the target (line-suffix match, allowing unrelated lines in
between), then insert the added lines right after that anchor.  Deleted
lines and multi-block hunks fall back to GNU patch; if that fails they
are reported for manual translation.

Usage: apply-hunks.py <target-file> <one-file-diff> [--apply]
  without --apply: print what would be inserted (review mode)
  with --apply: rewrite the target file
"""
import re
import sys


def split_hunks(diff_text):
    lines = diff_text.splitlines(True)
    i = 0
    while i < len(lines) and not lines[i].startswith('@@'):
        i += 1
    hunks = []
    cur = None
    for ln in lines[i:]:
        if ln.startswith('@@'):
            if cur is not None:
                hunks.append(cur)
            cur = {'hdr': ln, 'body': []}
        elif cur is not None:
            cur['body'].append(ln)
    if cur is not None:
        hunks.append(cur)
    return hunks


def anchor_insert(target_lines, ctx_lines, add_lines):
    """Find the anchor (last ctx line) in target, insert add_lines after
    the anchor's line (i.e. after the ctx block ends, but since we match
    the LAST ctx line, insert right after it). Returns new list or None."""
    if not ctx_lines:
        return None
    # use the last context line as the anchor; search from the end of
    # target backwards so we insert at the earliest sensible location
    anchor = ctx_lines[-1].rstrip('\n').strip()
    if not anchor:
        return None
    for idx in range(len(target_lines) - 1, -1, -1):
        if anchor and anchor in target_lines[idx]:
            ins = [a if a.endswith('\n') else a + '\n' for a in add_lines]
            return target_lines[:idx + 1] + ins + target_lines[idx + 1:]
    return None


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    target_path = sys.argv[1]
    diff_path = sys.argv[2]
    do_apply = '--apply' in sys.argv

    target = open(target_path).read().splitlines(True)
    diff_text = open(diff_path).read()
    hunks = split_hunks(diff_text)
    if not hunks:
        print("no hunks")
        return 1

    work = list(target)
    relocated = 0
    manual = []
    for h in hunks:
        body = h['body']
        ctx = [l for l in body if l.startswith(' ')]
        adds = [l[1:] for l in body if l.startswith('+')]
        dels = [l for l in body if l.startswith('-')]
        if not dels and adds:
            ctx_stripped = [c.rstrip('\n') for c in ctx]
            res = anchor_insert(work, ctx_stripped, adds)
            if res is not None:
                work = res
                relocated += 1
                continue
        # fallback: GNU patch on current work state
        import subprocess, tempfile, os
        with tempfile.NamedTemporaryFile('w', suffix='.patch', delete=False, dir='/mnt/WD10EZEX-TNFH/MVNonGKIDevices/.work') as tf:
            tf.write('--- a/%s\n+++ b/%s\n' % (os.path.basename(target_path), os.path.basename(target_path)))
            tf.write(h['hdr'])
            for l in body:
                tf.write(l)
            tfname = tf.name
        # apply patch to a temp copy of current file
        import shutil
        tmpf = target_path + '.work'
        with open(tmpf, 'w') as f:
            f.writelines(work)
        r = subprocess.run(['patch', '-p1', '-f', '-i', tfname], capture_output=True,
                           text=True, cwd=os.path.dirname(target_path))
        os.unlink(tfname)
        if r.returncode == 0:
            work = open(tmpf).read().splitlines(True)
            os.unlink(tmpf)
            relocated += 1
        else:
            os.unlink(tmpf)
            manual.append(h['hdr'].strip())

    if do_apply:
        open(target_path, 'w').writelines(work)
    print(f"relocated {relocated}/{len(hunks)} hunks")
    if manual:
        print(f"MANUAL {len(manual)}:")
        for m in manual:
            print("  ", m)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
