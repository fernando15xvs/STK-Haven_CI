package com.Fernando_S_ac.gym_tracker

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * OS-side expiration of the transient workout-rest chronometer (ID 998).
 *
 * The Flutter isolate may be suspended or the process killed while the
 * countdown is displayed. timeoutAfter on the notification is the primary
 * cleanup; this AlarmManager receiver is the backup on affected Android OEMs.
 *
 * It NEVER plays sound or touches media/audio focus, and NEVER cancels the
 * distinct final-rest alert (ID 999). A deadline token protects a newer rest
 * against an old broadcast delivered after an extension or Skip.
 */
class StkRestCountdownExpiryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val scheduled = intent.getLongExtra(EXTRA_DEADLINE, -1L)
        val current = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong(KEY_DEADLINE, -1L)
        if (scheduled <= 0L || scheduled != current ||
            System.currentTimeMillis() < scheduled) {
            return
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        manager.cancel(ONGOING_REST_NOTIFICATION_ID)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove(KEY_DEADLINE).apply()
    }

    companion object {
        private const val PREFS = "stk_rest_notification_deadline"
        private const val KEY_DEADLINE = "rest_end_epoch_millis"
        private const val EXTRA_DEADLINE = "expected_end_epoch_millis"
        private const val REQUEST_CODE = 99842
        private const val ONGOING_REST_NOTIFICATION_ID = 998

        private fun alarmIntent(context: Context, endMillis: Long): PendingIntent {
            val intent = Intent(context, StkRestCountdownExpiryReceiver::class.java)
                .putExtra(EXTRA_DEADLINE, endMillis)
            return PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun cancel(context: Context) {
            val alarms = context.getSystemService(Context.ALARM_SERVICE)
                as AlarmManager
            alarms.cancel(alarmIntent(context, -1L))
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .remove(KEY_DEADLINE).apply()
        }

        fun schedule(context: Context, endMillis: Long): Boolean {
            cancel(context)
            if (endMillis <= System.currentTimeMillis()) {
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
                    as NotificationManager
                manager.cancel(ONGOING_REST_NOTIFICATION_ID)
                return false
            }
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putLong(KEY_DEADLINE, endMillis).apply()
            val alarms = context.getSystemService(Context.ALARM_SERVICE)
                as AlarmManager
            val pendingIntent = alarmIntent(context, endMillis)
            try {
                when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                        !alarms.canScheduleExactAlarms() ->
                        alarms.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP, endMillis, pendingIntent,
                        )
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                        alarms.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP, endMillis, pendingIntent,
                        )
                    else ->
                        alarms.setExact(
                            AlarmManager.RTC_WAKEUP, endMillis, pendingIntent,
                        )
                }
            } catch (_: SecurityException) {
                // Exact alarms can be restricted/revoked at runtime.
                alarms.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, endMillis, pendingIntent,
                )
            }
            return true
        }
    }
}
