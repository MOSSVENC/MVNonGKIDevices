# setuid-hook 4.17- — ReSukiSU manual-integrate doc excerpt (reference)

Source: https://resukisu.org/zh-Hans/guide/manual-integrate.html
Note: 4.17- shape (hook SYSCALL_DEFINE3(setresuid) body)

```diff
diff --git a/kernel/sys.c b/kernel/sys.c
index a3bef5bd..0b116d7c 100644
--- a/kernel/sys.c
+++ b/kernel/sys.c
@@ -835,6 +843,9 @@
        return retval;
 }

+#ifdef CONFIG_KSU_MANUAL_HOOK
+extern int ksu_handle_setresuid(uid_t ruid, uid_t euid, uid_t suid);
+#endif

 /*
  * This function implements a generic ability to update ruid, euid,
@@ -848,6 +859,10 @@
        int retval;
        kuid_t kruid, keuid, ksuid;

+#ifdef CONFIG_KSU_MANUAL_HOOK
+       (void)ksu_handle_setresuid(ruid, euid, suid);
+#endif
+
        kruid = make_kuid(ns, ruid);
        keuid = make_kuid(ns, euid);
        ksuid = make_kuid(ns, suid);
```
