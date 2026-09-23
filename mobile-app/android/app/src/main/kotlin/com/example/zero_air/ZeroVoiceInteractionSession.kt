package com.example.zero_air

import android.content.Context
import android.content.Intent
import android.service.voice.VoiceInteractionSession
import android.os.Bundle

class ZeroVoiceInteractionSession(context: Context) : VoiceInteractionSession(context) {
    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        // When the user triggers the assistant (e.g., long pressing power/home button),
        // we launch our app's main activity.
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("wake_live_voice", true)
        }
        context.startActivity(intent)
    }
}
