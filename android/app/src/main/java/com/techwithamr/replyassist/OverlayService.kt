package com.techwithamr.replyassist

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.concurrent.thread

class OverlayService : Service() {
  private val handler = Handler(Looper.getMainLooper())
  private var window: WindowManager? = null
  private var bubble: View? = null

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    startFg()
    window = getSystemService(WINDOW_SERVICE) as WindowManager
    val view = LayoutInflater.from(this).inflate(R.layout.overlay_bubble, null)
    bubble = view
    val launch = view.findViewById<Button>(R.id.launch)
    val menu = view.findViewById<View>(R.id.menu)
    val status = view.findViewById<TextView>(R.id.status)
    val tones = view.findViewById<LinearLayout>(R.id.tones)
    listOf(
      "agree" to "Agree",
      "supportive" to "Supportive",
      "humor" to "Humor",
      "experience" to "Experience",
      "question" to "Question",
      "story" to "Story",
      "bold" to "Bold",
    ).forEach { (id, label) ->
      val btn = Button(this)
      btn.text = label
      btn.textSize = 12f
      btn.setOnClickListener { runTone(id, label, status) }
      tones.addView(btn)
    }
    launch.setOnClickListener {
      menu.visibility = if (menu.visibility == View.VISIBLE) View.GONE else View.VISIBLE
    }
    val params = WindowManager.LayoutParams(
      WindowManager.LayoutParams.WRAP_CONTENT,
      WindowManager.LayoutParams.WRAP_CONTENT,
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
      else
        @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
      WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
      PixelFormat.TRANSLUCENT,
    )
    params.gravity = Gravity.TOP or Gravity.END
    params.x = 12
    params.y = 120
    try {
      window?.addView(view, params)
    } catch (_: Exception) {
      stopSelf()
    }
  }

  private fun runTone(tone: String, label: String, status: TextView) {
    val key = Prefs.apiKey(this)
    if (key.isBlank()) {
      status.text = "المفتاح فاضي. افتح التطبيق والصقه."
      return
    }
    val a11y = TwaA11yService.instance
    if (a11y == null) {
      status.text = "شغّل خدمة الوصول من الإعدادات."
      return
    }
    status.text = "بيصيغ $label…"
    thread {
      try {
        val post = a11y.screenText()
        val messages = Voice.buildMessages(this, a11y.platform(), post, "", tone)
        val drafts = OpenAi.createDrafts(key, messages)
        val draft = drafts.first()
        val ok = a11y.insertDraft(draft)
        handler.post {
          status.text = if (ok) "اتكتب · ${Voice.MODEL}" else "اتولدت بس ما اتنكتبتش. انسخها يدوي."
        }
      } catch (err: Exception) {
        handler.post { status.text = err.message ?: "فشل التوليد" }
      }
    }
  }

  override fun onDestroy() {
    bubble?.let { runCatching { window?.removeView(it) } }
    bubble = null
    super.onDestroy()
  }

  private fun startFg() {
    val channel = "twa_overlay"
    val mgr = getSystemService(NotificationManager::class.java)
    mgr.createNotificationChannel(
      NotificationChannel(channel, "TWA overlay", NotificationManager.IMPORTANCE_LOW)
    )
    val open = PendingIntent.getActivity(
      this,
      0,
      Intent(this, MainActivity::class.java),
      PendingIntent.FLAG_IMMUTABLE,
    )
    val n = Notification.Builder(this, channel)
      .setContentTitle("TWA Reply Assist")
      .setContentText("الأيقونة شغالة. النشر يدوي.")
      .setSmallIcon(R.drawable.ic_twa)
      .setContentIntent(open)
      .build()
    startForeground(7, n)
  }

  companion object {
    fun ensure(context: Context) {
      val i = Intent(context, OverlayService::class.java)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(i)
      else context.startService(i)
    }

    fun showIcon(context: Context) {
      ensure(context)
    }
  }
}
