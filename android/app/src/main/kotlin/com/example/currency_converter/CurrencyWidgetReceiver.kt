package com.example.currency_converter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class CurrencyWidgetReceiver : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val fromCurrency = widgetData.getString("from_currency", "USD") ?: "USD"
            val toCurrency = widgetData.getString("to_currency", "EUR") ?: "EUR"
            val rate = widgetData.getString("exchange_rate", "--") ?: "--"
            val lastUpdated = widgetData.getString("last_updated", "") ?: ""
            val rateLabel = "1 $fromCurrency = $rate $toCurrency"
            val rate10 = widgetData.getString("rate_10", "--") ?: "--"
            val rate50 = widgetData.getString("rate_50", "--") ?: "--"
            val rate100 = widgetData.getString("rate_100", "--") ?: "--"
            val rate250 = widgetData.getString("rate_250", "--") ?: "--"

            // Build three layout variants and let Android pick based on actual size
            val small = buildRemoteViews(context, R.layout.currency_widget_small,
                fromCurrency, toCurrency, rate, lastUpdated, rateLabel,
                rate10, rate50, rate100, rate250)
            val medium = buildRemoteViews(context, R.layout.currency_widget_layout,
                fromCurrency, toCurrency, rate, lastUpdated, rateLabel,
                rate10, rate50, rate100, rate250)
            val wide = buildRemoteViews(context, R.layout.currency_widget_wide,
                fromCurrency, toCurrency, rate, lastUpdated, rateLabel,
                rate10, rate50, rate100, rate250)

            // Size breakpoints (width × height in dp)
            val viewMapping = mapOf(
                SizeF(120f, 50f) to small,   // Tiny: 2×1 cells
                SizeF(180f, 80f) to medium,  // Default: 3×2 cells
                SizeF(280f, 50f) to wide,    // Wide: 4×1 cells
            )

            val responsiveViews = RemoteViews(viewMapping)
            appWidgetManager.updateAppWidget(widgetId, responsiveViews)
        }
    }

    private fun buildRemoteViews(
        context: Context,
        layoutId: Int,
        fromCurrency: String,
        toCurrency: String,
        rate: String,
        lastUpdated: String,
        rateLabel: String,
        rate10: String,
        rate50: String,
        rate100: String,
        rate250: String
    ): RemoteViews {
        val views = RemoteViews(context.packageName, layoutId)
        views.setTextViewText(R.id.widget_from_currency, fromCurrency)
        views.setTextViewText(R.id.widget_to_currency, toCurrency)
        views.setTextViewText(R.id.widget_rate, rate)
        views.setTextViewText(R.id.widget_last_updated, lastUpdated)
        views.setTextViewText(R.id.widget_rate_label, rateLabel)
        views.setTextViewText(R.id.widget_title, "Currency Converter")
        views.setTextViewText(R.id.widget_rate_10, "10 → $rate10")
        views.setTextViewText(R.id.widget_rate_50, "50 → $rate50")
        views.setTextViewText(R.id.widget_rate_100, "100 → $rate100")
        views.setTextViewText(R.id.widget_rate_250, "250 → $rate250")
        return views
    }
}
