/** One voice contract for every draft. Do not add a second persona file. */

export const TWA_VOICE_CONTRACT = "twa-reply-assist: one Amr Gamal / Tech With Amr voice, draft-only, never auto-post";

export const DEFAULT_MODEL = "gpt-4.1-mini";

export const CONTEXT_SPLIT = "\n---\n";

export const TONES = [
  { id: "agree", labelAr: "موافقة", labelEn: "Agree" },
  { id: "supportive", labelAr: "داعم", labelEn: "Supportive" },
  { id: "humor", labelAr: "خفة دم", labelEn: "Light humor" },
  { id: "experience", labelAr: "من الخبرة", labelEn: "From experience" },
  { id: "question", labelAr: "سؤال ذكي", labelEn: "Smart question" },
  { id: "story", labelAr: "قصة سريعة", labelEn: "Quick story" },
  { id: "bold", labelAr: "جرأة", labelEn: "Bold take" },
  { id: "custom", labelAr: "مخصص", labelEn: "Custom" },
];

const PLATFORM_LIMITS = {
  linkedin: "LinkedIn: 2–4 جمل قصيرة. نبرة مهنية بشرية. بدون هاشتاج سبام.",
  facebook: "Facebook: 1–3 جمل طبيعية. عامية مهذبة لو البوست عربي.",
  youtube: "YouTube: 1–2 جملة. رد على التعليق نفسه، مش إعلان.",
  x: "X: جملة أو جملتين. حاد وواضح. من غير خيوط تسويق.",
  instagram: "Instagram: جملة قصيرة طبيعية. من غير هاشتاج سبام.",
  unknown: "علّق باختصار ووضوح.",
};

// <TWA_BRAND_VOICE>
export const BRAND_IDENTITY_SOURCE =
  "C:\\Github\\Remotion\\shared\\trends\\brand-signature.ts + brand-social-copy.ts";
export const BRAND_IDENTITY_VOICE =
  "شعار: وضوح تقني… قرار أهدى / Clear tech. Calmer decisions.\nوعد: تقنية واضحة لمهندسي IT أولًا — ثم المقاول والاستشاري — نحل مشكلة المشروع ونفتح باب مراجعة الشغل، مش درس تقني\nنبرة: بيّاع فاهم فنيًا · قريب من ألم العميل · عملي · يدعو للشغل من غير فذلكة ولا درس\nمجال: Data · Network · AV · ELV — محتوى تسويقي لمهندسي IT أولًا، ثم المقاول والاستشاري (مؤسسات وSME)؛ مالك المشروع = نفس ألم قرار البنية مع IT\nجمهور: مصر أولًا · مهندسو IT / مدير شبكات / مسؤول أنظمة (أساسي) · مقاول · استشاري · مالك المشروع يُعامل ضمن جمهور IT/صانع قرار البنية — مش جمهور رابع منفصل\nملخص المنصات: أساعد مهندسي IT والمقاولين والاستشاريين ياخدوا قرار بنية أوضح في مشاريع Data وNetwork وAV وELV — مراجعة مشروع، مش كورس.\nCTA المسموح فقط عند نبرة CTA: https://techwithamr.com/contact";
// </TWA_BRAND_VOICE>

export function sanitizeContext(text, max = 4000) {
  return String(text || "")
    .replace(/\u00a0/g, " ")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/[ \t]{2,}/g, " ")
    .trim()
    .slice(0, max);
}

export function combineContext(postText, commentText) {
  const post = sanitizeContext(postText);
  const comment = sanitizeContext(commentText, 2000);
  if (post && comment) return `${post}${CONTEXT_SPLIT}${comment}`;
  return post || comment;
}

export function splitContext(combined) {
  const text = String(combined || "");
  const idx = text.indexOf(CONTEXT_SPLIT);
  if (idx === -1) return { postText: text.trim(), commentText: "" };
  return {
    postText: text.slice(0, idx).trim(),
    commentText: text.slice(idx + CONTEXT_SPLIT.length).trim(),
  };
}

export function buildMessages({
  platform,
  postText,
  commentText,
  author,
  tone,
  language,
  extraVoice,
}) {
  const plat = PLATFORM_LIMITS[platform] || PLATFORM_LIMITS.unknown;
  const toneLine = {
    agree: "وافق على نقطة محددة من البوست بجملة عملية، من غير مدح فاضي.",
    supportive: "ادعم الكاتب باختصار، وأضف زاوية تقنية مفيدة.",
    humor: "خفة دم خفيفة ومهنية. نكتة واحدة كحد أقصى، من غير إيموجي زايد.",
    experience: "علّق من خبرة مشاريع Data/Network/AV/ELV في مصر أو المنطقة، من غير اختراع تفاصيل.",
    question: "اطرح سؤال تقني واحد ذكي يكمل النقاش.",
    story: "قصة سريعة من الواقع المهني في جملتين، مربوطة بالبوست.",
    bold: "رأي جريء واضح مع سبب واحد. محترم، مش هجومي.",
    custom: "اتبع تعليمات صاحب الحساب في حقل المخصص بحذافيرها.",
    professional: "نبرة مهنية هادئة، كأنك زميل مهندس مش محاضر.",
    warm: "نبرة ودّية قصيرة، من غير مبالغة أو إيموجي زايد.",
    thanks: "شكر محدد على نقطة واحدة من البوست أو التعليق.",
    cta: "CTA خفيف فقط إذا ناسب السياق. الرابط الوحيد المسموح: https://techwithamr.com/contact — لا تبيعه بقوة.",
  }[tone] || "نبرة مهنية هادئة.";

  const langLine =
    language === "ar"
      ? "اكتب بالعربي المصري المهني."
      : language === "en"
        ? "Write in clear professional English."
        : "طابق لغة البوست/التعليق. لو مختلط: عربي للعربي وإنجليزي للإنجليزي.";

  const extra = sanitizeContext(extraVoice, 800);

  const system = [
    "أنت تساعد عمرو جمال (Tech With Amr) يصيغ تعليقًا سيراجعه قبل النشر.",
    BRAND_IDENTITY_VOICE,
    "ممنوع: نشر تلقائي، مدح فاضي (Great post / محتوى رائع)، هاشتاج سبام، إيموجي كتير، ادعاء حضور فعالية لو مش مذكور، اختراع أرقام أو شهادات.",
    "لو السياق ناقص: اكتب ردًا حذرًا عامًا قصيرًا ولا تخمّن تفاصيل الحدث.",
    "أرجع JSON فقط بهذا الشكل: {\"drafts\":[\"...\",\"...\"]} مسودتان مختلفتان.",
    plat,
    toneLine,
    langLine,
    extra ? `تعليمات إضافية من صاحب الحساب: ${extra}` : "",
  ]
    .filter(Boolean)
    .join("\n");

  const user = [
    `المنصة: ${platform}`,
    author ? `كاتب البوست/الفيديو: ${sanitizeContext(author, 200)}` : "",
    `نص البوست أو الفيديو:\n${sanitizeContext(postText) || "(غير متوفر)"}`,
    commentText
      ? `التعليق المراد الرد عليه:\n${sanitizeContext(commentText, 2000)}`
      : "لا يوجد تعليق محدد — صِغ تعليقًا على البوست نفسه.",
  ]
    .filter(Boolean)
    .join("\n\n");

  return [
    { role: "system", content: system },
    { role: "user", content: user },
  ];
}

export function parseDrafts(raw) {
  const text = String(raw || "").trim();
  if (!text) return [];

  const fenced = text.match(/\{[\s\S]*\}/);
  const jsonBit = fenced ? fenced[0] : text;
  try {
    const parsed = JSON.parse(jsonBit);
    if (Array.isArray(parsed.drafts)) {
      return parsed.drafts.map((d) => sanitizeContext(d, 1200)).filter(Boolean).slice(0, 3);
    }
  } catch {
    // fall through
  }

  return text
    .split(/\n{2,}|^\s*(?:1[.)]|2[.)]|مسودة\s*\d)\s*/m)
    .map((d) => sanitizeContext(d, 1200))
    .filter((d) => d && !d.startsWith("{"))
    .slice(0, 2);
}
