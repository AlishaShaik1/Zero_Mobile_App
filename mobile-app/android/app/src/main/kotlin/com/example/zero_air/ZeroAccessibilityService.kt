package com.example.zero_air

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Rect
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.os.Bundle

object AccessibilityBridge {
    var service: ZeroAccessibilityService? = null
}

class ZeroAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        super.onServiceConnected()
        AccessibilityBridge.service = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // We poll the window state on demand, so we don't need to process every event here.
    }

    override fun onInterrupt() {
        // Interrupted
    }

    override fun onUnbind(intent: Intent?): Boolean {
        AccessibilityBridge.service = null
        return super.onUnbind(intent)
    }

    fun dumpTree(): String {
        val root = rootInActiveWindow ?: return "NO_TREE"
        val sb = java.lang.StringBuilder()
        dumpNode(root, sb, 0)
        return sb.toString()
    }

    private fun dumpNode(node: AccessibilityNodeInfo, sb: java.lang.StringBuilder, depth: Int) {
        if (!node.isVisibleToUser) return

        val text = node.text?.toString() ?: node.contentDescription?.toString() ?: ""
        val bounds = Rect()
        node.getBoundsInScreen(bounds)

        // Only include clickable, focusable, or text-bearing nodes to save tokens
        if (node.isClickable || node.isFocusable || text.isNotEmpty()) {
            val indent = " ".repeat(depth)
            val hashCode = node.hashCode() // Use hashcode as a pseudo-ID for clicking
            val clickable = if (node.isClickable) "[CLICKABLE]" else ""
            sb.append("$indent-$hashCode: \"$text\" $clickable\n")
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                dumpNode(child, sb, depth + 1)
                child.recycle()
            }
        }
    }

    fun performAction(actionStr: String): Boolean {
        val root = rootInActiveWindow ?: return false
        
        try {
            if (actionStr.startsWith("tap(")) {
                val idStr = actionStr.substringAfter("tap(").substringBefore(")")
                val id = idStr.toIntOrNull() ?: return false
                val target = findNodeById(root, id)
                return target?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false
            } else if (actionStr.startsWith("type(")) {
                val parts = actionStr.substringAfter("type(").substringBeforeLast(")")
                val idStr = parts.substringBefore(",").trim()
                val text = parts.substringAfter(",").trim().removeSurrounding("\"")
                val id = idStr.toIntOrNull() ?: return false
                val target = findNodeById(root, id)
                if (target != null) {
                    val arguments = Bundle()
                    arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                    return target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                }
                return false
            } else if (actionStr.startsWith("scroll(")) {
                val dir = actionStr.substringAfter("scroll(").substringBefore(")").lowercase()
                return if (dir == "up") {
                    // scrolling up means pulling content down to see higher items, which is backward
                    root.performAction(AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD) || 
                    findScrollable(root)?.performAction(AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD) ?: false
                } else {
                    root.performAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD) || 
                    findScrollable(root)?.performAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD) ?: false
                }
            } else if (actionStr.startsWith("back(")) {
                return performGlobalAction(GLOBAL_ACTION_BACK)
            }
        } catch (e: Exception) {
            return false
        }
        return false
    }

    private fun findNodeById(root: AccessibilityNodeInfo, targetId: Int): AccessibilityNodeInfo? {
        if (root.hashCode() == targetId) return root
        for (i in 0 until root.childCount) {
            val child = root.getChild(i)
            if (child != null) {
                val found = findNodeById(child, targetId)
                if (found != null) return found
                child.recycle()
            }
        }
        return null
    }

    private fun findScrollable(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (root.isScrollable) return root
        for (i in 0 until root.childCount) {
            val child = root.getChild(i)
            if (child != null) {
                val found = findScrollable(child)
                if (found != null) return found
                child.recycle()
            }
        }
        return null
    }
}
