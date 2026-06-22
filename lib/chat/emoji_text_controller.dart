//
//  emoji_text_controller.dart
//
//  A TextEditingController that supports inline Telegram custom (premium) emoji
//  inside the composer. Each inserted custom emoji is stored as a private-use
//  placeholder code unit (U+E000+); buildTextSpan renders those as inline
//  animated emoji, and toFormatted() converts the field to TDLib formattedText
//  (replacing each placeholder with its fallback emoji + a
//  textEntityTypeCustomEmoji entity at the correct UTF-16 offset).
//

import 'package:flutter/material.dart';

import 'custom_emoji.dart';

typedef _Emoji = ({int id, String fallback});

class EmojiTextEditingController extends TextEditingController {
  final Map<int, _Emoji> _byCode = {}; // PUA code unit -> emoji
  final Map<int, int> _codeForId = {}; // custom_emoji_id -> PUA code unit
  int _next = 0xE000; // BMP Private Use Area (single UTF-16 unit each)

  /// Inserts a custom emoji at the current selection.
  void insertCustomEmoji(int id, String fallback) {
    var code = _codeForId[id];
    if (code == null) {
      code = _next++;
      _codeForId[id] = code;
      _byCode[code] = (id: id, fallback: fallback.isEmpty ? '🙂' : fallback);
    }
    final ch = String.fromCharCode(code);
    final sel = selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, ch);
    value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + ch.length),
    );
  }

  /// Inserts plain text (e.g. a standard unicode emoji) at the selection.
  void insertText(String s) {
    final sel = selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, s);
    value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + s.length),
    );
  }

  bool get hasContent => text.trim().isNotEmpty;

  /// Converts the field to (plainText, entities) for inputMessageText.
  (String, List<Map<String, dynamic>>) toFormatted() {
    final buf = StringBuffer();
    final entities = <Map<String, dynamic>>[];
    var outLen = 0; // UTF-16 length written so far
    for (final unit in text.codeUnits) {
      final emoji = _byCode[unit];
      if (emoji != null) {
        final fb = emoji.fallback;
        entities.add({
          '@type': 'textEntity',
          'offset': outLen,
          'length': fb.length,
          'type': {
            '@type': 'textEntityTypeCustomEmoji',
            'custom_emoji_id': emoji.id.toString(),
          },
        });
        buf.write(fb);
        outLen += fb.length;
      } else {
        buf.writeCharCode(unit);
        outLen += 1;
      }
    }
    return (buf.toString(), entities);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_byCode.isEmpty) {
      return TextSpan(style: style, text: text);
    }
    final spans = <InlineSpan>[];
    final sb = StringBuffer();
    void flush() {
      if (sb.isNotEmpty) {
        spans.add(TextSpan(text: sb.toString()));
        sb.clear();
      }
    }

    for (final unit in text.codeUnits) {
      final emoji = _byCode[unit];
      if (emoji != null) {
        flush();
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: CustomEmojiView(id: emoji.id, size: 22, color: style?.color),
          ),
        );
      } else {
        sb.writeCharCode(unit);
      }
    }
    flush();
    return TextSpan(style: style, children: spans);
  }
}
