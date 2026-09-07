#!/usr/bin/env bash
#
# susfs-adapt-4.9.sh — stock-4.9 adaptation of two SuSFS hook files.
#
#   - fs/stat.c:         generic_fillattr / vfs_getattr_nosec use the stock
#                        4.9 signatures (2-arg, no result_mask); the
#                        SUS_KSTAT spoof hook is inserted accordingly.
#   - fs/proc/task_mmu.c: show_map_vma() has the stock 4.9 two-block shape
#                        (dev/ino block, then print block); SUS_MAP /
#                        SUS_KSTAT / OPEN_REDIRECT hooks are placed in the
#                        first block before show_vma_header_prefix().
#
# Run from the kernel root after the SuSFS hook-point base is applied and
# before susfs_inline_hook_patches-4.9.sh. Idempotent.
#
set -euo pipefail

[ -f fs/susfs.c ] || { echo "ERROR: fs/susfs.c not found — apply the SuSFS hook-point base first" >&2; exit 1; }

# ---------- fs/stat.c ----------
python3 - <<'PYEOF'
p = 'fs/stat.c'
s = open(p).read()

# 1. extern for the spoof helper (after asm/unistd.h include)
if 'susfs_sus_kstat_spoof_generic_fillattr' not in s.split('void generic_fillattr')[0]:
    s = s.replace(
        '#include <asm/uaccess.h>\n#include <asm/unistd.h>\n',
        '#include <asm/uaccess.h>\n#include <asm/unistd.h>\n\n'
        '#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT\n'
        'extern void susfs_sus_kstat_spoof_generic_fillattr(struct inode *inode, struct kstat *stat);\n'
        '#endif\n', 1)

# 2. generic_fillattr() tail spoof (stock 4.9: ends at stat->blocks, no result_mask)
head = s.split('EXPORT_SYMBOL(generic_fillattr)')[0]
if 'susfs_sus_kstat_spoof_generic_fillattr(inode, stat);' not in head:
    old = '\tstat->blksize = i_blocksize(inode);\n\tstat->blocks = inode->i_blocks;\n}'
    new = ('\tstat->blksize = i_blocksize(inode);\n\tstat->blocks = inode->i_blocks;\n'
           '#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT\n'
           '\tsusfs_sus_kstat_spoof_generic_fillattr(inode, stat);\n'
           '#endif\n}')
    assert old in head, 'generic_fillattr tail not found'
    s = s.replace(old, new, 1)

# 3. vfs_getattr_nosec(): stock 4.9 is 2-arg with old-style ->getattr(path->mnt,
#    path->dentry, stat); route successful getattr through the spoof too.
old = '''int vfs_getattr_nosec(struct path *path, struct kstat *stat)
{
	struct inode *inode = d_backing_inode(path->dentry);

	if (inode->i_op->getattr)
		return inode->i_op->getattr(path->mnt, path->dentry, stat);

	generic_fillattr(inode, stat);
	return 0;
}'''
new = '''int vfs_getattr_nosec(struct path *path, struct kstat *stat)
{
	struct inode *inode = d_backing_inode(path->dentry);

	if (inode->i_op->getattr) {
		int err = inode->i_op->getattr(path->mnt, path->dentry, stat);
#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
		if (!err)
			susfs_sus_kstat_spoof_generic_fillattr(inode, stat);
#endif
		return err;
	}

	generic_fillattr(inode, stat);
	return 0;
}'''
assert old in s, 'vfs_getattr_nosec not found'
s = s.replace(old, new, 1)

open(p, 'w').write(s)
print('fs/stat.c adapted')
PYEOF

# ---------- fs/proc/task_mmu.c ----------
python3 - <<'PYEOF'
p = 'fs/proc/task_mmu.c'
s = open(p).read()

old = '''	if (file) {
		struct inode *inode = file_inode(vma->vm_file);
		dev = inode->i_sb->s_dev;
		ino = inode->i_ino;
		pgoff = ((loff_t)vma->vm_pgoff) << PAGE_SHIFT;
	}'''
new = r'''	if (file) {
		struct inode *inode = file_inode(vma->vm_file);
#ifdef CONFIG_KSU_SUSFS_SUS_MAP
		if (SUSFS_IS_INODE_SUS_MAP(inode))
			return;
#endif // #ifdef CONFIG_KSU_SUSFS_SUS_MAP
		dev = inode->i_sb->s_dev;
		ino = inode->i_ino;
		pgoff = ((loff_t)vma->vm_pgoff) << PAGE_SHIFT;
#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
		susfs_sus_kstat_spoof_show_map_vma(inode, &dev, &ino);
#endif // #ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT
		if (SUSFS_IS_INODE_OPEN_REDIRECT(inode)) {
			char *spoofed_redirected_name = NULL;
			int srcu_idx = srcu_read_lock(&susfs_srcu_open_redirect);
			int ret = susfs_open_redirect_spoof_show_map_vma_srcu(inode, &ino, &dev, &spoofed_redirected_name);
			if (!ret) {
				pgoff = ((loff_t)vma->vm_pgoff) << PAGE_SHIFT;
				start = vma->vm_start;
				end = vma->vm_end;
				show_vma_header_prefix(m, start, end, flags, pgoff, dev, ino);
				seq_pad(m, ' ');
				if (spoofed_redirected_name)
					seq_puts(m, spoofed_redirected_name);
				seq_putc(m, '\n');
				srcu_read_unlock(&susfs_srcu_open_redirect, srcu_idx);
				return;
			}
			srcu_read_unlock(&susfs_srcu_open_redirect, srcu_idx);
		}
#endif // #ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT
	}'''
assert old in s, 'show_map_vma first block not found'
s = s.replace(old, new, 1)
open(p, 'w').write(s)
print('fs/proc/task_mmu.c adapted')
PYEOF

rm -f fs/stat.c.rej fs/proc/task_mmu.c.rej
echo "susfs-adapt-4.9.sh: done"
