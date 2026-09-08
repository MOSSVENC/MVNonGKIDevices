# sys_read-hook 4.19+ — ReSukiSU manual-integrate doc excerpt (reference)

Source: https://resukisu.org/zh-Hans/guide/manual-integrate.html
Note: 4.19+ shape (wrapper over ksys_read)

```diff
--- a/fs/read_write.c
+++ b/fs/read_write.c
@@ -568,11 +568,21 @@
 		file->f_pos = pos;
 }
 
+#ifdef CONFIG_KSU_MANUAL_HOOK
+extern bool ksu_init_rc_hook __read_mostly;
+extern __attribute__((cold)) int ksu_handle_sys_read(unsigned int fd,
+				char __user **buf_ptr, size_t *count_ptr);
+#endif
+
 SYSCALL_DEFINE3(read, unsigned int, fd, char __user *, buf, size_t, count)
 {
 	struct fd f = fdget_pos(fd);
 	ssize_t ret = -EBADF;
 
+#ifdef CONFIG_KSU_MANUAL_HOOK
+	if (unlikely(ksu_init_rc_hook)) 
+		ksu_handle_sys_read(fd, &buf, &count);
+#endif
 	if (f.file) {
 		loff_t pos = file_pos_read(f.file);
 		ret = vfs_read(f.file, buf, count, &pos);
```
