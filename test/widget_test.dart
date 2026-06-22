// Unit tests for the ported pure logic (date formatting, JSON helpers, parsing).

import 'package:mithkal/tdlib/json_helpers.dart';
import 'package:mithkal/tdlib/td_models.dart';
import 'package:mithkal/theme/date_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateText', () {
    test('bubbleLabel pads to HH:mm', () {
      final unix = DateTime(2024, 6, 4, 9, 5).millisecondsSinceEpoch ~/ 1000;
      expect(DateText.bubbleLabel(unix), '09:05');
    });

    test('empty for non-positive unix', () {
      expect(DateText.listLabel(0), '');
      expect(DateText.separatorLabel(0), '');
    });
  });

  group('JSON helpers', () {
    test('parses TDLib int64-as-string', () {
      final obj = <String, dynamic>{'order': '123456789012345', 'n': 7};
      expect(obj.int64('order'), 123456789012345);
      expect(obj.integer('n'), 7);
      expect(obj.str('missing'), isNull);
    });
  });

  group('TDParse.messageText', () {
    test('photo with no caption → [图片]', () {
      final content = <String, dynamic>{'@type': 'messagePhoto'};
      expect(TDParse.messageText(content), '[图片]');
    });

    test('plain text passes through', () {
      final content = <String, dynamic>{
        '@type': 'messageText',
        'text': {'@type': 'formattedText', 'text': 'hello'},
      };
      expect(TDParse.messageText(content), 'hello');
    });
  });
}
