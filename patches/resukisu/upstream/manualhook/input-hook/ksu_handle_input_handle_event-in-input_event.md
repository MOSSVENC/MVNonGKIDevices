# input-hook  — ReSukiSU manual-integrate doc excerpt (reference)

Source: https://resukisu.org/zh-Hans/guide/manual-integrate.html
Note: no version split in the doc; hook input_event

```diff
--- a/drivers/input/input.c
+++ b/drivers/input/input.c
@@ -436,11 +436,22 @@
  * to 'seed' initial state of a switch or initial position of absolute
  * axis, etc.
  */
+#ifdef CONFIG_KSU_MANUAL_HOOK
+extern bool ksu_input_hook __read_mostly;
+extern __attribute__((cold)) int ksu_handle_input_handle_event(
+			unsigned int *type, unsigned int *code, int *value);
+#endif
+
 void input_event(struct input_dev *dev,
 		 unsigned int type, unsigned int code, int value)
 {
 	unsigned long flags;
 
+#ifdef CONFIG_KSU_MANUAL_HOOK
+	if (unlikely(ksu_input_hook))
+		ksu_handle_input_handle_event(&type, &code, &value);
+#endif
+
 	if (is_event_supported(type, dev->evbit, EV_MAX)) {
 
 		spin_lock_irqsave(&dev->event_lock, flags);
```
