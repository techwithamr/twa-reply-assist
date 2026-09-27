# TWA Reply Assist

إضافة كروم تصيغ تعليقات **Tech With Amr** بعد قراءة البوست.

المنصات: LinkedIn · Facebook · YouTube · X · Instagram.

مسار واحد: قراءة سياق → GPT → مسودة. **النشر يدوي دائمًا.**

الإصدار الحالي: `1.4.3`

## تثبيت على أي جهاز

1. انسخ المشروع أو: `git clone <رابط-الريبو>`
2. افتح كروم على `chrome://extensions`
3. فعّل **Developer mode**
4. **Load unpacked** واختار مجلد المشروع (اللي فيه `manifest.json`)
5. Details → Site access → **On all sites**
6. ثبّت أيقونة TWA في الشريط
7. اضغط الأيقونة والصق مفتاح OpenAI ثم **حفظ**
8. افتح LinkedIn (أو المنصة) واضغط أيقونة TWA — الشريط البرتقالي يظهر فوق الصفحة
9. افتح خانة `Add a comment` على البوست، اختَر نبرة (مثل Agree)، راجع المسودة، وانشر بنفسك

الموديل الافتراضي: `gpt-4.1-mini`

بعد كل `git pull`: اضغط **Reload** على بطاقة الإضافة، ثم حدّث تبويب LinkedIn.

المفتاح يتسجل في كروم فقط. لا تضعه في الملفات ولا في Git.

## تطوير من أي مكان

```bash
git clone <رابط-الريبو>
cd twa-reply-assist
```

افتح المجلد في Cursor. بعد التعديل:

```bash
git add -A
git commit -m "وصف التغيير"
git push
```

على جهاز التشغيل: `git pull` ثم Reload للإضافة.

الهوية من Remotion (`brand-signature.ts` + ملخص المنصات):

```bash
node scripts/sync-brand-voice.mjs
```
