package com.techwithamr.replyassist

import android.accessibilityservice.AccessibilityService
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class TwaA11yService : AccessibilityService() {
  override fun onServiceConnected() {
    instance = this
    OverlayService.ensure(this)
  }

  override fun onAccessibilityEvent(event: AccessibilityEvent?) {
    if (event == null) return
    val src = event.source
    val editable = src?.isEditable == true || src?.className?.toString()?.contains("EditText") == true
    if (editable) {
      focused = AccessibilityNodeInfo.obtain(src)
      OverlayService.showIcon(this)
    }
    src?.recycle()
  }

  override fun onInterrupt() {}

  override fun onDestroy() {
    if (instance === this) instance = null
    super.onDestroy()
  }

  fun screenText(): String {
    val root = rootInActiveWindow ?: return ""
    val out = StringBuilder()
    walk(root, out)
    root.recycle()
    return out.toString().trim().take(2500)
  }

  fun insertDraft(text: String): Boolean {
    val node = focused ?: findFocusedEdit() ?: return false
    val args = Bundle()
    args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
    val ok = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    if (!ok) {
      node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
      val paste = Bundle()
      paste.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
      return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, paste)
    }
    return true
  }

  fun platform(): String = Voice.detectPlatform(rootInActiveWindow?.packageName?.toString() ?: "")

  private fun findFocusedEdit(): AccessibilityNodeInfo? {
    val root = rootInActiveWindow ?: return null
    val found = findEdit(root)
    if (found == null) root.recycle()
    return found
  }

  private fun findEdit(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
    if (node.isEditable && node.isFocused) return node
    for (i in 0 until node.childCount) {
      val child = node.getChild(i) ?: continue
      val hit = findEdit(child)
      if (hit != null) {
        if (hit !== child) child.recycle()
        return hit
      }
      child.recycle()
    }
    return null
  }

  private fun walk(node: AccessibilityNodeInfo, out: StringBuilder) {
    val t = node.text?.toString()?.trim().orEmpty()
    val d = node.contentDescription?.toString()?.trim().orEmpty()
    val piece = if (t.length > d.length) t else d
    if (piece.length > 2 && !node.isPassword) {
      out.append(piece).append('\n')
    }
    for (i in 0 until node.childCount) {
      val child = node.getChild(i) ?: continue
      walk(child, out)
      child.recycle()
    }
  }

  companion object {
    @Volatile
    var instance: TwaA11yService? = null
      private set

    @Volatile
    var focused: AccessibilityNodeInfo? = null
  }
}
