import 'package:intl/intl.dart';

final DateFormat _dayMonthYear = DateFormat('dd/MM/yyyy');
final DateFormat _ymd = DateFormat('yyyy-MM-dd');

/// Formats a number as Vietnamese money: 1234000 -> "1.234.000 ₫"
String money(num? value) {
  if (value == null) return '— ₫';
  final v = value.round();
  final negative = v < 0;
  final digits = v.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer ₫';
}

/// 1500000 -> "1.500.000" (no currency symbol, used inside inputs/labels).
String moneyGrouped(num? value) {
  if (value == null) return '0';
  return money(value).replaceAll(' ₫', '');
}

/// Strips every non-digit character. "1.500.000" -> 1500000
int parseMoneyOnlyDigits(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(cleaned) ?? 0;
}

/// "12,5" or "12.5" -> 12.5 (quantity input). Null-safe.
double? parseQuantity(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  return double.tryParse(normalized);
}

/// dd/MM/yyyy
String shortDate(DateTime d) => _dayMonthYear.format(d);

/// yyyy-MM-dd (used when sending DATE values to Supabase)
String sqlDate(DateTime d) => _ymd.format(d);

/// Vietnamese day-of-week for headers: "Thứ 2, 05/08"
String weekdayLabel(DateTime d) {
  const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  return '${days[d.weekday - 1]}, ${_dayMonthYear.format(d)}';
}

/// "2,5 kg" for product+quantity chips.
String quantityLabel(double qty, String unit) {
  final q = qty == qty.roundToDouble()
      ? qty.round().toString()
      : qty.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  return '$q $unit';
}
