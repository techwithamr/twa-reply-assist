package com.techwithamr.replyassist

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_main)
    val keyBox = findViewById<EditText>(R.id.apiKey)
    val status = findViewById<TextView>(R.id.status)
    keyBox.setText(Prefs.apiKey(this))
    findViewById<Button>(R.id.saveKey).setOnClickListener {
      Prefs.setApiKey(this, keyBox.text.toString())
      status.text = if (Prefs.apiKey(this).isNotBlank()) "اتحفظ · ${Voice.MODEL}" else "المفتاح فاضي."
    }
    findViewById<Button>(R.id.overlayBtn).setOnClickListener {
      startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
    }
    findViewById<Button>(R.id.a11yBtn).setOnClickListener {
      startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
    }
    findViewById<Button>(R.id.startBtn).setOnClickListener {
      if (!Settings.canDrawOverlays(this)) {
        status.text = "اسمح أولًا بالأيقونة فوق التطبيقات."
        return@setOnClickListener
      }
      OverlayService.ensure(this)
      status.text = "الأيقونة اشتغلت. افتح تطبيق واكتب رد."
    }
  }

  override fun onResume() {
    super.onResume()
    refresh()
  }

  private fun refresh() {
    val overlay = Settings.canDrawOverlays(this)
    val a11y = TwaA11yService.instance != null
    val key = Prefs.apiKey(this).isNotBlank()
    findViewById<TextView>(R.id.status).text =
      "مفتاح: ${if (key) "موجود" else "ناقص"} · أيقونة: ${if (overlay) "مسموحة" else "مقفولة"} · وصول: ${if (a11y) "شغال" else "مقفول"} · ${Voice.MODEL}"
  }
}
