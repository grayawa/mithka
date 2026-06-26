// Unit tests for the ported pure logic (date formatting, JSON helpers, parsing).

import 'package:mithka/tdlib/json_helpers.dart';
import 'package:mithka/tdlib/td_models.dart';
import 'package:mithka/settings/translation_controller.dart';
import 'package:mithka/theme/date_text.dart';
import 'package:mithka/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('TDParse.messageButtonRows', () {
    test('parses inline keyboard url and callback buttons', () {
      final rows = TDParse.messageButtonRows({
        '@type': 'replyMarkupInlineKeyboard',
        'rows': [
          [
            {
              '@type': 'inlineKeyboardButton',
              'text': 'Open',
              'type': {
                '@type': 'inlineKeyboardButtonTypeUrl',
                'url': 'https://example.com',
              },
            },
            {
              '@type': 'inlineKeyboardButton',
              'text': 'Tap',
              'type': {
                '@type': 'inlineKeyboardButtonTypeCallback',
                'data': 'abc',
              },
            },
          ],
        ],
      });

      expect(rows, hasLength(1));
      expect(rows.first, hasLength(2));
      expect(rows.first[0].text, 'Open');
      expect(rows.first[0].url, 'https://example.com');
      expect(rows.first[1].isCallback, isTrue);
      expect(rows.first[1].data, 'abc');
    });

    test('parses reply keyboard text buttons', () {
      final rows = TDParse.messageButtonRows({
        '@type': 'replyMarkupShowKeyboard',
        'rows': [
          [
            {
              '@type': 'keyboardButton',
              'text': 'OK',
              'type': {'@type': 'keyboardButtonTypeText'},
            },
          ],
        ],
      });

      expect(rows.single.single.text, 'OK');
      expect(rows.single.single.type, 'keyboardButtonTypeText');
      expect(rows.single.single.isReplyKeyboard, isTrue);
    });
  });

  group('TDParse.linkPreview', () {
    test('parses title, full description, and article photo', () {
      final preview = TDParse.linkPreview({
        '@type': 'linkPreview',
        'url': 'https://example.com/rich',
        'display_url': 'example.com/rich',
        'site_name': 'Example',
        'title': 'Rich Message Demo',
        'description': {
          '@type': 'formattedText',
          'text': 'Select a screen\n- Text Formatting\n- Code & Pre',
          'entities': [
            {
              '@type': 'textEntity',
              'offset': 18,
              'length': 15,
              'type': {'@type': 'textEntityTypeBold'},
            },
          ],
        },
        'type': {
          '@type': 'linkPreviewTypeArticle',
          'photo': {
            '@type': 'photo',
            'sizes': [
              {
                '@type': 'photoSize',
                'width': 320,
                'height': 180,
                'photo': {'@type': 'file', 'id': 42},
              },
            ],
          },
        },
        'show_large_media': true,
        'show_media_above_description': true,
        'show_above_text': false,
      });

      expect(preview, isNotNull);
      expect(preview!.title, 'Rich Message Demo');
      expect(preview.description, contains('Text Formatting'));
      expect(preview.descriptionEntities.single.type, 'textEntityTypeBold');
      expect(preview.image?.id, 42);
      expect(preview.imageWidth, 320);
      expect(preview.imageHeight, 180);
      expect(preview.showLargeMedia, isTrue);
    });
  });

  group('AppFontChoice', () {
    test('applies primary font before CJK and system fallbacks', () {
      final style = AppFontChoice.futura.applyTextStyle(
        const TextStyle(fontSize: 16),
        cjkFallback: AppFontChoice.pingFangTw,
      );

      expect(style.fontFamily, 'Futura');
      expect(style.fontFamilyFallback, isNotNull);
      expect(style.fontFamilyFallback!.first, 'PingFang TC');
      expect(style.fontFamilyFallback!, contains('Helvetica Neue'));
    });

    test('custom font families override preset font families', () {
      final style = AppFontChoice.futura.applyTextStyle(
        const TextStyle(fontSize: 16),
        cjkFallback: AppFontChoice.pingFangTw,
        customPrimaryFamily: 'My Latin',
        customCjkFamily: 'My CJK',
      );

      expect(style.fontFamily, 'My Latin');
      expect(style.fontFamilyFallback, isNotNull);
      expect(style.fontFamilyFallback!.first, 'My CJK');
      expect(style.fontFamilyFallback!.length, greaterThan(1));
    });
  });

  group('TranslationController', () {
    test('defaults off and persists target/no-translate preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = TranslationController(prefs);

      expect(controller.enabled, isFalse);
      expect(controller.autoTranslate, isFalse);
      expect(controller.provider, TranslationProvider.tdlib);
      expect(controller.targetLanguageCode, 'auto');
      expect(controller.noTranslateLanguageCodes, isEmpty);
      expect(
        controller.lingvaEndpoint,
        TranslationController.defaultLingvaEndpoint,
      );
      expect(controller.libreTranslateEndpoint, isEmpty);

      controller.enabled = true;
      controller.autoTranslate = true;
      controller.provider = TranslationProvider.myMemory;
      controller.targetLanguageCode = 'ja';
      controller.setNoTranslateLanguage('en', true);
      controller.lingvaEndpoint = 'https://lingva.example.com/';
      controller.libreTranslateEndpoint = ' https://libre.example.com// ';

      final reloaded = TranslationController(prefs);
      expect(reloaded.enabled, isTrue);
      expect(reloaded.autoTranslate, isTrue);
      expect(reloaded.provider, TranslationProvider.myMemory);
      expect(reloaded.targetLanguageCode, 'ja');
      expect(reloaded.noTranslateLanguageCodes, contains('en'));
      expect(reloaded.lingvaEndpoint, 'https://lingva.example.com');
      expect(reloaded.libreTranslateEndpoint, 'https://libre.example.com');
    });

    test('detects common no-translate language families', () {
      expect(TranslationController.detectLanguage('你好，今天怎么样'), 'zh');
      expect(TranslationController.detectLanguage('これはテストです'), 'ja');
      expect(TranslationController.detectLanguage('this is the test'), 'en');
      expect(
        TranslationController.detectLanguage('este es el texto para traducir'),
        'es',
      );
      expect(
        TranslationController.detectLanguage(
          'Bonjour, je suis très content de vous voir',
        ),
        'fr',
      );
      expect(
        TranslationController.detectLanguage(
          'Das ist nicht für dich, sondern für mich',
        ),
        'de',
      );
      expect(
        TranslationController.detectLanguage('não sei se você está aqui agora'),
        'pt',
      );
      expect(TranslationController.detectLanguage('ok lol'), '');
    });
  });
}
