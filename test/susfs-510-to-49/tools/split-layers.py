#!/usr/bin/env python3
"""
split-layers.py — split a rebuilt monolithic patch into the four
deliverable layers (same grouping as patches/susfs/0001-0004).

Usage: split-layers.py <rebuilt.patch> <out-dir>
"""
import os
import sys

GROUPS = {
    '0001-susfs-core.patch': [
        'fs/susfs.c', 'include/linux/susfs.h', 'include/linux/susfs_def.h'],
    '0002-susfs-vfs-hooks.patch': [
        'fs/Makefile', 'fs/namespace.c', 'fs/notify/fdinfo.c',
        'fs/proc/base.c', 'fs/proc/cmdline.c', 'fs/proc/fd.c',
        'fs/proc/task_mmu.c', 'fs/proc_namespace.c', 'fs/readdir.c',
        'fs/statfs.c', 'kernel/kallsyms.c', 'mm/memory.c',
        'security/selinux/avc.c'],
    '0003-susfs-ksu-hooks.patch': [
        'drivers/input/input.c', 'fs/exec.c', 'fs/open.c',
        'fs/read_write.c', 'kernel/reboot.c',
        'security/selinux/hooks.c', 'security/selinux/ss/services.c'],
    '0004-susfs-overlay.patch': ['fs/namei.c', 'fs/stat.c', 'kernel/sys.c'],
}


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    patch, outdir = sys.argv[1], sys.argv[2]
    text = open(patch).read()
    segs = {}
    for x in text.split('diff --git ')[1:]:
        segs[x.split(' b/')[1].split()[0]] = 'diff --git ' + x
    for name, files in GROUPS.items():
        with open(os.path.join(outdir, name), 'w') as f:
            for fn in files:
                if fn in segs:
                    f.write(segs[fn])
        print('wrote', name)
    return 0


if __name__ == '__main__':
    sys.exit(main())
