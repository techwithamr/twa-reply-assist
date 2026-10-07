package com.techwithamr.replyassist

import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

object OpenAi {
  fun createDrafts(apiKey: String, messages: List<ChatMessage>): List<String> {
    val arr = JSONArray()
    messages.forEach { msg ->
      arr.put(JSONObject().put("role", msg.role).put("content", msg.content))
    }
    val body = JSONObject()
      .put("model", Voice.MODEL)
      .put("messages", arr)
      .put("temperature", 0.7)
      .put("max_tokens", 400)
      .put("response_format", JSONObject().put("type", "json_object"))
    val conn = URL("https://api.openai.com/v1/chat/completions").openConnection() as HttpURLConnection
    conn.requestMethod = "POST"
    conn.setRequestProperty("Authorization", "Bearer $apiKey")
    conn.setRequestProperty("Content-Type", "application/json")
    conn.doOutput = true
    conn.connectTimeout = 20000
    conn.readTimeout = 45000
    OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body.toString()) }
    val code = conn.responseCode
    val stream = if (code in 200..299) conn.inputStream else conn.errorStream
    val raw = stream.bufferedReader().use { it.readText() }
    if (code !in 200..299) {
      val detail = try {
        JSONObject(raw).optJSONObject("error")?.optString("message")
      } catch (_: Exception) {
        null
      }
      throw IllegalStateException(detail ?: "HTTP $code")
    }
    val content = JSONObject(raw)
      .optJSONArray("choices")
      ?.optJSONObject(0)
      ?.optJSONObject("message")
      ?.optString("content")
      ?: ""
    val drafts = Voice.parseDrafts(content)
    if (drafts.isEmpty()) throw IllegalStateException("النموذج رجع ردًا فاضيًا.")
    return drafts
  }
}
