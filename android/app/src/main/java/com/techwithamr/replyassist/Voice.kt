package com.techwithamr.replyassist

import android.content.Context
import org.json.JSONObject

data class ChatMessage(val role: String, val content: String)

object Voice {
  const val MODEL = "gpt-4.1-mini"

  fun detectPlatform(pkg: String): String {
    val name = pkg.lowercase()
    return when {
      name.contains("linkedin") -> "linkedin"
      name.contains("facebook") -> "facebook"
      name.contains("instagram") -> "instagram"
      name.contains("youtube") -> "youtube"
      name.contains("twitter") || name.contains(".x.") || name.endsWith(".x") -> "x"
      else -> "unknown"
    }
  }

  fun detectReplyLanguage(text: String): String {
    val ar = text.count { it in '\u0600'..'\u06FF' }
    val en = text.count { it.isLetter() && it.code < 128 }
    if (ar >= 8 && ar >= en) return "ar"
    if (en >= 8 && en > ar) return "en"
    return "auto"
  }

  fun buildMessages(
    context: Context,
    platform: String,
    postText: String,
    commentText: String,
    tone: String,
  ): List<ChatMessage> {
    val raw = context.assets.open("twa-voice.json").bufferedReader().use { it.readText() }
    val json = JSONObject(raw)
    val brand = json.optString("brand")
    val platforms = json.optJSONObject("platforms")
    val toneLines = json.optJSONObject("toneLines")
    val plat = platforms?.optString(platform)?.ifBlank { null }
      ?: platforms?.optString("unknown")
      ?: "علّق باختصار ووضوح."
    val toneLine = toneLines?.optString(tone)?.ifBlank { null } ?: "نبرة مهنية هادئة."
    val resolved = detectReplyLanguage("$postText\n$commentText")
    val langLine = when (resolved) {
      "ar" -> "اكتب المسودة بالعربي فقط. ممنوع إنجليزي إلا أسماء تقنية."
      "en" -> "Write the draft in English only. Do not reply in Arabic to an English post."
      else -> "طابق لغة نص البوست حرفيًا. ممنوع ترد عربي على بوست إنجليزي أو العكس."
    }
    val system = listOf(
      "أنت تساعد عمرو جمال (Tech With Amr) يصيغ تعليقًا سيراجعه قبل النشر.",
      brand,
      "ممنوع: نشر تلقائي، مدح فاضي (Great post / محتوى رائع)، هاشتاج سبام، إيموجي كتير، ادعاء حضور فعالية لو مش مذكور، اختراع أرقام أو شهادات.",
      "لو السياق ناقص: اكتب ردًا حذرًا عامًا قصيرًا ولا تخمّن تفاصيل الحدث.",
      "الهوية للمعنى فقط. نص المسودة بلغة البوست، مش لغة الإعدادات الداخلية.",
      "أرجع JSON فقط بهذا الشكل: {\"drafts\":[\"...\",\"...\"]} مسودتان مختلفتان.",
      plat,
      toneLine,
      langLine,
    ).filter { it.isNotBlank() }.joinToString("\n")
    val user = listOf(
      "المنصة: $platform",
      "نص البوست أو الفيديو:\n${postText.ifBlank { "(غير متوفر)" }.take(4000)}",
      if (commentText.isNotBlank()) "التعليق المراد الرد عليه:\n${commentText.take(2000)}"
      else "لا يوجد تعليق محدد — صِغ تعليقًا على البوست نفسه.",
    ).joinToString("\n\n")
    return listOf(ChatMessage("system", system), ChatMessage("user", user))
  }

  fun parseDrafts(raw: String): List<String> {
    val text = raw.trim()
    if (text.isEmpty()) return emptyList()
    val start = text.indexOf('{')
    val end = text.lastIndexOf('}')
    if (start >= 0 && end > start) {
      try {
        val drafts = JSONObject(text.substring(start, end + 1)).optJSONArray("drafts")
        if (drafts != null) {
          return (0 until drafts.length())
            .map { drafts.optString(it).trim() }
            .filter { it.isNotEmpty() }
            .take(2)
        }
      } catch (_: Exception) {
        // fall through
      }
    }
    return text.split(Regex("\n{2,}")).map { it.trim() }.filter { it.isNotEmpty() && !it.startsWith("{") }.take(2)
  }
}
