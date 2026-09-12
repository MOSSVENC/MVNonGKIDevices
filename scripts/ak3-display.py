#!/usr/bin/env python3
"""Prepare the cloned AnyKernel3 tree and compose the flash-time display.

usage: ak3-display.py <ak3-dir> <device-codename> [name-out]

env: ROOT_MANAGER HOOK_TYPE
     ENABLE_BBG ENABLE_DROIDSPACE ENABLE_DATA_ISOLATION

Display: one left-aligned line —
    <codename>  <manager>  <hook> | <feature>  <feature> ...
hook names: ReSukiSU -> AUTO HOOK / SUSFS INLINE HOOK / MANUAL HOOK;
XXKSU -> SUSFS INLINE HOOK / SYSCALL TABLE HOOK / BRANCH LINK HOOK.
features follow BBG > DROIDSPACE > SDCARDFS; absent ones are
omitted. Package name: <codename>_<manager>_<hook>[_<feature>...].zip,
hook token SUSFS / AUTO / MANUAL / SYSCALL_TABLE / BRANCH_LINK.

Writes inside <ak3-dir>:
  banner        the line; AnyKernel3 prints this file line by line
  FEATURES.txt  the same line for at-a-glance package inspection
and rewrites two template files:
  anykernel.sh  kernel.string takes the same line; its parser is
                grep + tail + cut -d= -f2-, so the value stays one line
  META-INF/com/google/android/update-binary
                the installer's own print of kernel.string is commented
                out, so the flash log carries the display once.
                The property stays in place: the installer reads it as the
                ak3-helper module description.
A template without the line to rewrite is reported on stderr; the print
then stays and the flash log shows the display twice.

The upstream template also ships a tuna (Galaxy Nexus) sample ramdisk edit
between dump_boot and write_boot (init.rc cgroup tweak, init.tuna.rc,
fstab.tuna).  On these devices those files do not exist, so the sample
lines only produce helper errors and an init.tuna.rc file appended into
the repacked ramdisk; the boot install block keeps only its two calls.
"""
import os
import re
import sys

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
    hook, token = {'auto': ('AUTO HOOK', 'AUTO'),
                   'susfs': ('SUSFS INLINE HOOK', 'SUSFS'),
                   }.get(ht, ('MANUAL HOOK', 'MANUAL'))
elif rm == 'xxksu':
    manager = 'XXKSU'
    hook, token = {'susfs': ('SUSFS INLINE HOOK', 'SUSFS'),
                   'syscall_table': ('SYSCALL TABLE HOOK', 'SYSCALL_TABLE'),
                   'branch_link': ('BRANCH LINK HOOK', 'BRANCH_LINK'),
                   }.get(ht, ('HOOK', ''))
else:
    manager = 'STOCK'
    hook = token = ''

line1 = '  '.join(x for x in (dev, manager, hook) if x)
line2 = '  '.join(feats)
display = line1 + (' | ' + line2 if line2 else '')

# banner: the flash display line (AnyKernel3 prints it with ui_printfile)
with open(os.path.join(ak3_dir, 'banner'), 'w') as fh:
    fh.write(display + '\n')

# FEATURES.txt: the same line, kept in the package for inspection
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


# kernel.string: the same line, so the single-line property parser keeps it
one_line = display
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

# The installer echoes kernel.string right below the banner — the same
# line.  Comment that echo out so the flash log carries the display once;
# line 402 of the same file keeps reading the property as the ak3-helper
# module description.
ub_path = os.path.join(ak3_dir, 'META-INF/com/google/android/update-binary')
ub_print = 'ui_print "$KERNEL_STRING";'
ub_suppressed = '# kernel string shown by the banner above'
ub = open(ub_path).read()
if ub_print in ub:
    open(ub_path, 'w').write(ub.replace(ub_print, ub_suppressed, 1))
elif ub_suppressed not in ub:
    sys.stderr.write('ak3-display: update-binary has no kernel-string echo '
                     'line; the flash log keeps the duplicate\n')

name = '_'.join(x for x in ([dev, manager, token] + feats) if x) + '.zip'
if name_out:
    with open(name_out, 'w') as fh:
        fh.write(name + '\n')

print(display)
