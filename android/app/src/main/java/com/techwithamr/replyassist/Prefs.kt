package com.techwithamr.replyassist

import android.content.Context

object Prefs {
  private const val FILE = "twa_reply"
  private const val KEY = "apiKey"

  fun apiKey(context: Context): String =
    context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getString(KEY, "") ?: ""

  fun setApiKey(context: Context, value: String) {
    context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().putString(KEY, value.trim()).apply()
  }
}
