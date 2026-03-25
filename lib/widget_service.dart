import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class WidgetService {
  static const _tableAmounts = [10, 50, 100, 250];

  static String _fmt(double v) {
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(0)}k';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v >= 100) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  /// Pushes the latest conversion data to the Android home screen widget.
  static Future<void> updateWidget({
    required String fromCurrency,
    required String toCurrency,
    required double rate,
  }) async {
    final now = DateFormat('MMM d, h:mm a').format(DateTime.now());

    await Future.wait([
      HomeWidget.saveWidgetData<String>('from_currency', fromCurrency),
      HomeWidget.saveWidgetData<String>('to_currency', toCurrency),
      HomeWidget.saveWidgetData<String>(
          'exchange_rate', rate.toStringAsFixed(4)),
      HomeWidget.saveWidgetData<String>('last_updated', 'Updated $now'),
      ...(_tableAmounts.map(
        (a) => HomeWidget.saveWidgetData<String>('rate_$a', _fmt(a * rate)),
      )),
    ]);

    await HomeWidget.updateWidget(
      androidName: 'CurrencyWidgetReceiver',
    );
  }
}
