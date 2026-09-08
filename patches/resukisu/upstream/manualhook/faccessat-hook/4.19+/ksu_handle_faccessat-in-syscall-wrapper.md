# faccessat-hook 4.19+ — ReSukiSU manual-integrate doc excerpt (reference)

Source: https://resukisu.org/zh-Hans/guide/manual-integrate.html
Note: 4.19+ shape (thin wrapper over do_faccessat)

```diff
--- a/fs/open.c
+++ b/fs/open.c
@@ -354,6 +354,11 @@
 	return error;
 }
 
+#ifdef CONFIG_KSU_MANUAL_HOOK
+__attribute__((hot)) 
+extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user,
+				int *mode, int *flags);
+#endif
+
 /*
  * access() needs to use the real uid/gid, not the effective uid/gid.
  * We do this by temporarily clearing all FS-related capabilities and
@@ -369,6 +374,10 @@
 	int res;
 	unsigned int lookup_flags = LOOKUP_FOLLOW;
 
+#ifdef CONFIG_KSU_MANUAL_HOOK
+	ksu_handle_faccessat(&dfd, &filename, &mode, NULL);
+#endif
+
 	if (mode & ~S_IRWXO)	/* where's F_OK, X_OK, W_OK, R_OK? */
 		return -EINVAL;
```
