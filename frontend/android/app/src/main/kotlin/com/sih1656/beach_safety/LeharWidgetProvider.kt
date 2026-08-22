package com.sih1656.beach_safety

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Home screen widget showing a beach's current safety rating.
 *
 * The hero photograph changes with the rating — sunset when conditions are
 * calm, open blue water when they are moderate, a storm when they are high —
 * so the widget reads at a glance from across a room, before any of the
 * numbers are legible.
 *
 * Everything drawn here comes from what the app last saved. The widget never
 * talks to the service itself: a widget cannot rely on the network being
 * reachable or the backend being awake, and showing a stale reading honestly
 * labelled beats showing an error.
 */
class LeharWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = HomeWidgetPlugin.getData(context)
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(id, buildViews(context, data))
        }
    }

    private fun buildViews(context: Context, data: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.lehar_widget)

        // "low" | "moderate" | "high", written by the app. Anything else means
        // the app has not run yet, and the calm image is the honest default
        // because no rating has been measured — not because it is safe.
        val risk = data.getString(KEY_RISK, null)

        views.setImageViewResource(R.id.widget_hero, heroFor(risk))
        views.setTextViewText(R.id.widget_temperature, data.getString(KEY_TEMPERATURE, "--"))
        views.setTextViewText(R.id.widget_risk, riskLabel(risk))
        views.setTextViewText(
            R.id.widget_beach,
            data.getString(KEY_BEACH, context.getString(R.string.app_name)),
        )

        views.setTextViewText(R.id.widget_wave, data.getString(KEY_WAVE, "--"))
        views.setTextViewText(R.id.widget_wind, data.getString(KEY_WIND, "--"))
        views.setTextViewText(R.id.widget_uv, data.getString(KEY_UV, "--"))
        views.setTextViewText(R.id.widget_tide, data.getString(KEY_TIDE, "--"))

        // Tapping anywhere opens the app, which is also how the widget gets
        // fresh data — there is nothing else the user could usefully tap.
        launchIntent(context)?.let { views.setOnClickPendingIntent(R.id.widget_root, it) }

        return views
    }

    private fun heroFor(risk: String?): Int = when (risk) {
        "high" -> R.drawable.hero_high
        "moderate" -> R.drawable.hero_moderate
        else -> R.drawable.hero_low
    }

    private fun riskLabel(risk: String?): String = when (risk) {
        "high" -> "HIGH RISK"
        "moderate" -> "MODERATE RISK"
        "low" -> "LOW RISK"
        else -> "NO DATA YET"
    }

    private fun launchIntent(context: Context): PendingIntent? {
        val intent = context.packageManager
            .getLaunchIntentForPackage(context.packageName) ?: return null
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private companion object {
        const val KEY_RISK = "widget_risk"
        const val KEY_BEACH = "widget_beach"
        const val KEY_TEMPERATURE = "widget_temperature"
        const val KEY_WAVE = "widget_wave"
        const val KEY_WIND = "widget_wind"
        const val KEY_UV = "widget_uv"
        const val KEY_TIDE = "widget_tide"
    }
}
