#!/usr/bin/env python3
"""Prepare the cloned AnyKernel3 tree and compose the flash-time display.

usage: ak3-display.py <ak3-dir> <device-codename> [name-out]

env: ROOT_MANAGER
     ENABLE_BBG ENABLE_DROIDSPACE ENABLE_DATA_ISOLATION
     CENTER_WIDTH (optional, default 60)

Display: two centered lines —
    <codename>  <manager>
    <feature>  <feature> ...
features follow BBG > DROIDSPACE > SDCARDFS; absent ones are
omitted. Package name: <codename>_<manager>[_<feature>...].zip

Writes inside <ak3-dir>:
  banner        the two lines; AnyKernel3 prints this file line by line
  FEATURES.txt  the same two lines for at-a-glance package inspection
and rewrites kernel.string in anykernel.sh with the one-line form of the
same content.  kernel.string is read by AnyKernel3 through a single-line
property parser (grep + tail + cut -d= -f2-), so a value spanning lines
there yields only the first one; the line-by-line banner is what carries
the full display.

The upstream template also ships a tuna (Galaxy Nexus) sample ramdisk edit
between dump_boot and write_boot (init.rc cgroup tweak, init.tuna.rc,
fstab.tuna).  On these devices those files do not exist, so the sample
lines only produce helper errors and an init.tuna.rc file appended into
the repacked ramdisk; the boot install block keeps only its two calls.
"""
import os
import re
import sys

CENTER_WIDTH = int(os.environ.get('CENTER_WIDTH', '60'))

ak3_dir = sys.argv[1]
dev = sys.argv[2]
name_out = sys.argv[3] if len(sys.argv) > 3 else None

rm = os.environ.get('ROOT_MANAGER', 'none')

feat_flags = [
    ('BBG', os.environ.get('ENABLE_BBG') == 'true'),
    ('DROIDSPACE', os.environ.get('ENABLE_DROIDSPACE') == 'true'),
    ('SDCARDFS', os.environ.get('ENABLE_DATA_ISOLATION') == 'true'),
]
feats = [name for name, on in feat_flags if on]

if rm == 'resukisu':
    manager = 'ReSukiSU'
elif rm == 'xxksu':
    manager = 'XXKSU'
else:
    manager = 'STOCK'

line1 = '  '.join(x for x in (dev, manager) if x)
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

def strip_template_sample(text):
    """Drop the template's sample ramdisk edit from the boot install block.

    Everything between the boot `dump_boot` call and the following
    `write_boot` call is template sample content; the device flash needs
    only the two calls.  Commented sample blocks elsewhere in the file
    stay untouched because they do not start with the call names.  A
    template without either call is returned unchanged.
    """
    if not re.search(r'(?m)^\s*dump_boot', text) or \
       not re.search(r'(?m)^\s*write_boot', text):
        return text
    out = []
    in_boot_install = False
    for line in text.split('\n'):
        stripped = line.strip()
        if stripped.startswith('dump_boot'):
            in_boot_install = True
            out.append(line)
            continue
        if in_boot_install and stripped.startswith('write_boot'):
            in_boot_install = False
            out.append(line)
            continue
        if in_boot_install:
            continue
        out.append(line)
    return '\n'.join(out)


# kernel.string: one line, so the single-line property parser keeps it
one_line = line1 + ('  |  ' + line2 if line2 else '')
sh_path = os.path.join(ak3_dir, 'anykernel.sh')
s = strip_template_sample(open(sh_path).read())
m = re.search(r'(?m)^kernel\.string=(.*)$', s)
if not m:
    sys.stderr.write('ak3-display: anykernel.sh has no kernel.string line\n')
    sys.exit(1)
end = m.end()
value = m.group(1)
if value[:1] == '"':
    # value opens with a quote on the kernel.string line: the matching
    # closing quote ends it (a quoted value may span lines)
    close = s.find('"', m.start(1) + 1)
    if close != -1:
        end = close + 1
# no surrounding quotes in the written value: the properties() body is a
# single-quoted string, and AnyKernel3 would show the quote characters
s = s[:m.start()] + 'kernel.string=' + one_line + s[end:]
open(sh_path, 'w').write(s)

name = '_'.join(x for x in ([dev, manager] + feats) if x) + '.zip'
if name_out:
    with open(name_out, 'w') as fh:
        fh.write(name + '\n')

print(display)
