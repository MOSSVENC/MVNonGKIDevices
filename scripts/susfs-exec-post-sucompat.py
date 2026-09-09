#!/usr/bin/env python3
"""Idempotently inject the susfs post-execve su-compat call into fs/exec.c.

Required with current ReSukiSU su_fd: after a su session the
post_execveat_sucompat call installs the su fd.  Kept in a standalone
script so the workflow's run block stays YAML-safe.
usage: susfs-exec-post-sucompat.py <fs/exec.c path>
"""
import sys

p = sys.argv[1]
s = open(p).read()

if 'extern int ksu_handle_post_execveat_sucompat' not in s:
    s = s.replace(
        'extern int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr,\n'
        '\t\t\t\t void *argv, void *envp, int *flags);',
        'extern int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr,\n'
        '\t\t\t\t void *argv, void *envp, int *flags);\n'
        'extern int ksu_handle_post_execveat_sucompat(int *fd, struct filename **filename_ptr, void *argv,\n'
        '\t\t\t void *envp, int *flags, int *retval);', 1)

if 'is_su_session' not in s:
    s = s.replace(
        '\tif (likely(susfs_is_current_proc_no_su()))\n'
        '\t\tgoto orig_flow;',
        '\tbool is_su_session = false;\n'
        '\tif (likely(susfs_is_current_proc_no_su()))\n'
        '\t\tgoto orig_flow;', 1)
    s = s.replace(
        '\t\tif (static_branch_unlikely(&susfs_is_sdcard_android_data_not_decrypted))\n'
        '\t\tksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);\n'
        '\telse\n'
        '\t\tksu_handle_execveat_sucompat(&fd, &filename, &argv, &envp, &flags);',
        '\t\tif (static_branch_unlikely(&susfs_is_sdcard_android_data_not_decrypted))\n'
        '\t\t\tis_su_session = !ksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);\n'
        '\t\telse\n'
        '\t\t\tis_su_session = !ksu_handle_execveat_sucompat(&fd, &filename, &argv, &envp, &flags);', 1)
    s = s.replace(
        'orig_flow:\n#endif',
        'orig_flow:\n'
        '\tif (unlikely(is_su_session))\n'
        '\t\t(void)ksu_handle_post_execveat_sucompat(&fd, &filename, &argv, &envp, &flags, &retval);\n'
        '#endif', 1)

open(p, 'w').write(s)