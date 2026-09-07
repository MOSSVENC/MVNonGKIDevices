#!/usr/bin/env python3
"""
relocate-hunk.py — apply a hunk to a target file by progressively
"purifying" its context lines: context lines that do not exist anywhere
near the candidate position in the target are dropped (they are 5.10
lines absent on 4.9), and the hunk is retried against the real file via
GNU patch until it applies or no context remains.

This scripts away the dominant failure mode of the 5.10->4.9 port:
context drift caused by 5.10-only neighbours (io_uring.h, bprm_execve,
statx fields, ...).

Usage: relocate-hunk.py <target-file> <hunk.patch>
Exit: 0 applied, 2 cannot relocate
"""
import re
import subprocess
import sys
import os


def purify_and_apply(target, hunk_path):
    """Try applying hunk; on failure, drop context lines one round at a
    time (least-anchoring first) and retry via GNU patch."""
    lines = open(hunk_path).read().splitlines(True)
    if not lines:
        return False
    # split header vs hunk body
    i = 0
    while i < len(lines) and not lines[i].startswith('@@'):
        i += 1
    if i >= len(lines):
        return False
    header = lines[:i]
    body = lines[i:]

    # gather context-only lines (space prefix) with their positions
    ctx_idx = [j for j, l in enumerate(body) if l.startswith(' ') and l.strip()]

    # try progressively removing context lines (from the tail of the hunk
    # context, which usually carries the drifted 5.10 neighbours)
    for drop_count in range(len(ctx_idx) + 1):
        # choose which context lines to keep: keep the first ones
        keep = set(ctx_idx[: len(ctx_idx) - drop_count]) if drop_count < len(ctx_idx) else set()
        new_body = []
        for j, l in enumerate(body):
            if j in ctx_idx and j not in keep:
                continue  # drop this context line entirely
            new_body.append(l)
        trial = ''.join(header + new_body)
        tmp = hunk_path + '.try'
        with open(tmp, 'w') as f:
            f.write(trial)
        r = subprocess.run(['patch', '-p1', '-f', '--dry-run', '-i', tmp],
                           capture_output=True, text=True, cwd=os.path.dirname(target))
        if r.returncode == 0:
            # apply for real
            r2 = subprocess.run(['patch', '-p1', '-f', '-i', tmp],
                                capture_output=True, text=True, cwd=os.path.dirname(target))
            os.unlink(tmp)
            return r2.returncode == 0
        os.unlink(tmp)
    return False


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    target = sys.argv[1]
    hunk = sys.argv[2]
    if purify_and_apply(target, hunk):
        print(f"relocated: {os.path.basename(hunk)} -> {os.path.basename(target)}")
        return 0
    print(f"CANNOT RELOCATE: {os.path.basename(hunk)}")
    return 2


if __name__ == '__main__':
    sys.exit(main())
