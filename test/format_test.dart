import 'package:flutter_test/flutter_test.dart';
import 'package:quan_ly_rau/core/format.dart';

void main() {
  group('money formatting', () {
    test('groups thousands with dots and appends ₫', () {
      expect(money(1234000), '1.234.000 ₫');
      expect(money(0), '0 ₫');
      expect(money(500), '500 ₫');
    });

    test('handles negatives (losses)', () {
      expect(money(-250000), '-250.000 ₫');
    });

    test('moneyGrouped strips the symbol', () {
      expect(moneyGrouped(1500000), '1.500.000');
    });
  });

  group('input parsing', () {
    test('parseMoneyOnlyDigits ignores separators', () {
      expect(parseMoneyOnlyDigits('1.500.000'), 1500000);
      expect(parseMoneyOnlyDigits(''), 0);
    });

    test('parseQuantity accepts comma or dot decimals', () {
      expect(parseQuantity('2,5'), 2.5);
      expect(parseQuantity('2.5'), 2.5);
      expect(parseQuantity('abc'), isNull);
    });
  });

  group('dates', () {
    test('sqlDate is yyyy-MM-dd', () {
      expect(sqlDate(DateTime(2025, 1, 5)), '2025-01-05');
    });
  });
}
