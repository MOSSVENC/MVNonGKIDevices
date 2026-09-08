# setuid-hook 4.17+ — ReSukiSU manual-integrate doc excerpt (reference)

Source: https://resukisu.org/zh-Hans/guide/manual-integrate.html
Note: 4.17+ shape (hook __sys_setresuid)

```diff
diff --git a/kernel/sys.c b/kernel/sys.c
index 4a87dc5fa..aac25df8c 100644
--- a/kernel/sys.c
+++ b/kernel/sys.c
@@ -679,6 +679,10 @@
 }


+#ifdef CONFIG_KSU_MANUAL_HOOK
+extern int ksu_handle_setresuid(uid_t ruid, uid_t euid, uid_t suid);
+#endif
+
 /*
  * This function implements a generic ability to update ruid, euid,
  * and suid.  This allows you to implement the 4.4 compatible seteuid().
@@ -692,6 +696,10 @@
        kuid_t kruid, keuid, ksuid;
        bool ruid_new, euid_new, suid_new;

+#ifdef CONFIG_KSU_MANUAL_HOOK
+       (void)ksu_handle_setresuid(ruid, euid, suid);
+#endif
+
        kruid = make_kuid(ns, ruid);
        keuid = make_kuid(ns, euid);
        ksuid = make_kuid(ns, suid);
```
