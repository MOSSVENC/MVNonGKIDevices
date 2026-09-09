#!/usr/bin/env python3
"""Compose the AK3 kernel.string display from build inputs.

usage: ak3-display.py <anykernel.sh> <device-prefix>

env: ROOT_MANAGER ROOT_ENGINE HOOK_TYPE HOOK_EXTRA
     ENABLE_REKERNEL ENABLE_BBG ENABLE_DROIDSPACE ENABLE_DATA_ISOLATION

Display order: root manager, hook type, features (BBG > REKERNEL >
DROIDSPACE > SDCARDFS). Long content splits into one line per layer;
manual-hook detail is appended as separated description lines.
"""
import os
import re
import sys

sh_path, dev = sys.argv[1], sys.argv[2]
rm = os.environ.get('ROOT_MANAGER', 'none')
eng = os.environ.get('ROOT_ENGINE', '')
ht = os.environ.get('HOOK_TYPE', '')
hx = os.environ.get('HOOK_EXTRA', '')

feat_flags = [
    ('BBG', os.environ.get('ENABLE_BBG') == 'true'),
    ('REKERNEL', os.environ.get('ENABLE_REKERNEL') == 'true'),
    ('DROIDSPACE', os.environ.get('ENABLE_DROIDSPACE') == 'true'),
    ('SDCARDFS', os.environ.get('ENABLE_DATA_ISOLATION') == 'true'),
]
feats = [name for name, on in feat_flags if on]

if rm == 'none':
    text = dev + (' ' + ' '.join(feats) if feats else ' STOCK')
else:
    root = 'ReSukiSU' if rm == 'resukisu' else 'XXKSU'
    hook = ''
    desc = []
    if rm == 'resukisu':
        if ht == 'auto':
            hook = 'AUTO-HOOK'
            desc = ['auto-hook branch: inline-hook engine, no source patches']
        elif ht == 'susfs':
            hook = 'SUSFS-INLINE-HOOK'
            desc = ['SuSFS inline hook (kernel-side susfs, KSU call sites)']
        else:
            hook = 'MANUAL-HOOK'
            if hx == 'manual':
                desc = ['source patches + alt manual hooks (input/setuid/sys_read 0010-0012)']
            else:
                desc = [
                    'INPUT hook: auto-applied via kernel input_handler '
                    '(CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK)',
                    'SETUID/INITRC hooks: LSM AUTO',
                ]
    else:
        hook = {'syscall_table': 'SYSCALL-TABLE-HOOK',
                'branch_link': 'BRANCH-LINK-HOOK'}.get(eng, 'HOOK')
    head = '{} {} {}'.format(dev, root, hook)
    if feats:
        head += ' ' + ' '.join(feats)
    if len(head) <= 64 and not desc:
        text = head
    else:
        text = '\n'.join([dev + ' ' + root, hook] +
                         ([' '.join(feats)] if feats else []))
        if desc:
            text += '\n\n' + '\n'.join(desc)

s = open(sh_path).read()
s = re.sub(r'(?m)^kernel\.string=.*', 'kernel.string="' + text + '"', s, count=1)
open(sh_path, 'w').write(s)
