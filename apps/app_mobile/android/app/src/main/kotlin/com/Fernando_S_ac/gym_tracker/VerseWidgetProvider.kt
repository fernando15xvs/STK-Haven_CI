package com.Fernando_S_ac.gym_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Standard Android AppWidget, eligible for lock-screen placement only when
 * the system/launcher exposes lock-screen widgets. No unlock bypass.
 */
class VerseWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        ids.forEach { id -> update(context, manager, id) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_DATE_CHANGED ||
            intent.action == Intent.ACTION_TIMEZONE_CHANGED ||
            intent.action == Intent.ACTION_TIME_CHANGED
        ) {
            refreshAll(context)
        }
    }

    companion object {
        private const val PREF_FILE = "stk_verse_widget"

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, VerseWidgetProvider::class.java),
            )
            ids.forEach { update(context, manager, it) }
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val prefs = context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean("enabled", false)
            var text = if (enabled) prefs.getString("text", "") ?: "" else ""
            var reference = if (enabled) prefs.getString("reference", "") ?: "" else ""

            // Workmanager's Bible refresher writes SharedPreferences directly
            // in the background; use its snapshot if the date is newer.
            if (enabled) {
                val flutter = context.getSharedPreferences(
                    "FlutterSharedPreferences", Context.MODE_PRIVATE,
                )
                val backgroundDate = flutter.getString("flutter.daily_verse_date", "") ?: ""
                val cachedDate = prefs.getString("date", "") ?: ""
                if (dateKey(backgroundDate) > dateKey(cachedDate)) {
                    val updated = flutter.getString("flutter.saved_verse", "") ?: ""
                    val updatedRef = flutter.getString("flutter.saved_reference", "") ?: ""
                    if (updated.isNotBlank() && updatedRef.isNotBlank()) {
                        text = updated
                        reference = updatedRef
                    }
                }
            }

            val views = RemoteViews(context.packageName, R.layout.stk_verse_widget)
            views.setTextViewText(
                R.id.verse_widget_text,
                text.ifBlank { context.getString(R.string.stk_verse_widget_placeholder) },
            )
            views.setTextViewText(
                R.id.verse_widget_reference,
                reference.ifBlank { context.getString(R.string.stk_verse_widget_open_hint) },
            )

            val launch = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pending = PendingIntent.getActivity(
                context, 0, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.verse_widget_root, pending)
            manager.updateAppWidget(id, views)
        }

        private fun dateKey(raw: String): Int {
            val pieces = raw.split("-")
            if (pieces.size != 3) return 0
            val year = pieces[0].toIntOrNull() ?: return 0
            val month = pieces[1].toIntOrNull() ?: return 0
            val day = pieces[2].toIntOrNull() ?: return 0
            if (month !in 1..12 || day !in 1..31) return 0
            return year * 10000 + month * 100 + day
        }
    }
}
