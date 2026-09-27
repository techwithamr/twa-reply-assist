# TWA Reply Assist

إضافة كروم تصيغ تعليقات **Tech With Amr** بعد قراءة البوست.

المنصات: LinkedIn · Facebook · YouTube · X · Instagram.

مسار واحد: قراءة سياق → GPT → مسودة. **النشر يدوي دائمًا.**

## تثبيت (Developer)

1. افتح `chrome://extensions`
2. فعّل Developer mode
3. Load unpacked واختار `C:\Github\twa-reply-assist`
4. حط مفتاح OpenAI من أيقونة الإضافة أو الإعدادات
5. الموديل الافتراضي: `gpt-4.1-mini`

لو الإضافة كانت محمّلة قبل كده: اضغط Reload على البطاقة.

## استخدام

1. افتح خانة التعليق على البوست
2. زر **رد** يظهر فقط لو صندوق التعليق ظاهر — أو اضغط `Alt+Shift+R`
3. راجع المسودة → إدراج أو نسخ → انشر بنفسك

الهوية بتتجاب من Remotion (`brand-signature.ts` + ملخص المنصات). لتحديثها:

```bash
node scripts/sync-brand-voice.mjs
```
