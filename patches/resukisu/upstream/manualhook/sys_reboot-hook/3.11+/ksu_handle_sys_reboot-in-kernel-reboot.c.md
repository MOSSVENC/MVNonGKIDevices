# sys_reboot-hook 3.11+ — ReSukiSU manual-integrate doc excerpt (reference)

Source: https://resukisu.org/zh-Hans/guide/manual-integrate.html
Note: 3.11+ shape (SYSCALL_DEFINE4 in kernel/reboot.c)

```diff
--- a/kernel/reboot.c
+++ b/kernel/reboot.c
@@ -277,6 +277,11 @@
  *
  * reboot doesn't sync: do that yourself before calling this.
  */
+
+#ifdef CONFIG_KSU_MANUAL_HOOK
+extern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd, void __user **arg);
+#endif
+
 SYSCALL_DEFINE4(reboot, int, magic1, int, magic2, unsigned int, cmd,
 		void __user *, arg)
 {
@@ -284,6 +289,9 @@
 	char buffer[256];
 	int ret = 0;
 
+#ifdef CONFIG_KSU_MANUAL_HOOK
+	ksu_handle_sys_reboot(magic1, magic2, cmd, &arg);
+#endif
 	/* We only trust the superuser with rebooting the system. */
 	if (!ns_capable(pid_ns->user_ns, CAP_SYS_BOOT))
 		return -EPERM;
```
