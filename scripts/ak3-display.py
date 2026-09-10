#!/usr/bin/env python3
"""Compose the AK3 flash-time display and the package name from build inputs.

usage: ak3-display.py <anykernel.sh> <device-codename> [name-out]

env: ROOT_MANAGER HOOK_TYPE HOOK_EXTRA
     CENTER_WIDTH (optional, default 60)

Display: two centered lines —
    <codename>  <manager>  <HOOK_TYPE>
    <feature>  <feature> ...
omitted. Package name: <codename>_<manager>_<HOOK_TYPE>[_<feature>...].zip
"""
import os
import re
import sys

CENTER_WIDTH = int(os.environ.get('CENTER_WIDTH', '60'))

sh_path = sys.argv[1]
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


text = centered(line1)
if line2:
    text += '\n' + centered(line2)

name = '_'.join(x for x in ([dev, manager, hook] + feats) if x) + '.zip'

s = open(sh_path).read()
s = re.sub(r'(?m)^kernel\.string=.*', 'kernel.string="' + text + '"', s, count=1)
open(sh_path, 'w').write(s)
if name_out:
    open(name_out, 'w').write(name + '\n')
print(text)
