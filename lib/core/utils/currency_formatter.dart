import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static String format(num value) => _formatter.format(value);

  /// Format tanpa simbol "Rp", dipakai di struk supaya lebih ringkas
  static String formatPlain(num value) {
    final formatted = NumberFormat.decimalPattern('id_ID').format(value);
    return formatted;
  }
}
