import 'package:flutter_test/flutter_test.dart';
import 'package:mithkal/tdlib/td_models.dart';

void main() {
  test('formatPhone uses libphonenumber per-country grouping', () {
    expect(TDParse.formatPhone('61412345678'), '+61 412 345 678'); // AU
    expect(TDParse.formatPhone('8613800138000'), '+86 138 0013 8000'); // CN
    expect(TDParse.formatPhone('14155550123'), '+1 415-555-0123'); // US
    expect(TDParse.formatPhone('442071838750'), '+44 20 7183 8750'); // UK
    expect(TDParse.formatPhone(''), '');
    expect(TDParse.formatPhone(null), '');
  });
}
