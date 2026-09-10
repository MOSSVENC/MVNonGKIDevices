#!/usr/bin/env python3
"""Compose the AK3 flash-time display and the package name from build inputs.

usage: ak3-display.py <ak3-dir> <device-codename> [name-out]

env: ROOT_MANAGER HOOK_TYPE
     ENABLE_BBG ENABLE_DROIDSPACE ENABLE_DATA_ISOLATION
     CENTER_WIDTH (optional, default 60)

Display: two centered lines —
    <codename>  <manager>  <HOOK_TYPE>
    <feature>  <feature> ...
features follow BBG > DROIDSPACE > SDCARDFS; absent ones are
omitted. Package name: <codename>_<manager>_<HOOK_TYPE>[_<feature>...].zip

Writes inside <ak3-dir>:
  banner        the two lines; AnyKernel3 prints this file line by line
  FEATURES.txt  the same two lines for at-a-glance package inspection
and rewrites kernel.string in anykernel.sh with the one-line form of the
same content.  kernel.string is read by AnyKernel3 through a single-line
property parser (grep + tail + cut -d= -f2-), so a value spanning lines
there yields only the first one; the line-by-line banner is what carries
the full display.
"""
import os
import re
import sys

CENTER_WIDTH = int(os.environ.get('CENTER_WIDTH', '60'))

ak3_dir = sys.argv[1]
dev = sys.argv[2]
name_out = sys.argv[3] if len(sys.argv) > 3 else None

rm = os.environ.get('ROOT_MANAGER', 'none')
ht = os.environ.get('HOOK_TYPE', '')

feat_flags = [
    ('BBG', os.environ.get('ENABLE_BBG') == 'true'),
    ('DROIDSPACE', os.environ.get('ENABLE_DROIDSPACE') == 'true'),
    ('SDCARDFS', os.environ.get('ENABLE_DATA_ISOLATION') == 'true'),
]
feats = [name for name, on in feat_flags if on]

if rm == 'resukisu':
    manager = 'ReSukiSU'
    hook = {'auto': 'AUTO-HOOK', 'susfs': 'SUSFS-INLINE-HOOK'}.get(ht, 'MANUAL-HOOK')
elif rm == 'xxksu':
    manager = 'XXKSU'
    hook = 'SUSFS-INLINE-HOOK' if ht == 'susfs' else {
        'syscall_table': 'SYSCALL-TABLE-HOOK',
        'branch_link': 'BRANCH-LINK-HOOK',
    }.get(ht, 'HOOK')
else:
    manager = 'STOCK'
    hook = ''

line1 = '  '.join(x for x in (dev, manager, hook) if x)
line2 = '  '.join(feats)


def centered(text):
    if not text:
        return ''
    pad = max(0, (CENTER_WIDTH - len(text)) // 2)
    return ' ' * pad + text


display = centered(line1)
if line2:
    display += '\n' + centered(line2)

# banner: multi-line flash display (AnyKernel3 prints it with ui_printfile)
with open(os.path.join(ak3_dir, 'banner'), 'w') as fh:
    fh.write(display + '\n')

# FEATURES.txt: same content, kept in the package for inspection
with open(os.path.join(ak3_dir, 'FEATURES.txt'), 'w') as fh:
    fh.write(display + '\n')

# kernel.string: one line, so the single-line property parser keeps it
one_line = line1 + ('  |  ' + line2 if line2 else '')
sh_path = os.path.join(ak3_dir, 'anykernel.sh')
s = open(sh_path).read()
m = re.search(r'(?m)^kernel\.string=', s)
if not m:
    sys.stderr.write('ak3-display: anykernel.sh has no kernel.string line\n')
    sys.exit(1)
start = m.start()
quote = s.find('"', m.end())
end = s.find('\n', m.end())
if quote != -1:
    close = s.find('"', quote + 1)
    if close != -1:
        end = close + 1
# no surrounding quotes: the properties() body is a single-quoted
# string, and AnyKernel3 would show the quote characters otherwise
s = s[:start] + 'kernel.string=' + one_line + s[end:]
open(sh_path, 'w').write(s)

name = '_'.join(x for x in ([dev, manager, hook] + feats) if x) + '.zip'
if name_out:
    with open(name_out, 'w') as fh:
        fh.write(name + '\n')

print(display)
