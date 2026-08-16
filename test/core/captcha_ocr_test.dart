import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/core/auth/captcha_ocr.dart';

void main() {
  group('parseCaptchaGuess', () {
    test('抽出纯字母数字并小写', () {
      expect(parseCaptchaGuess('Sxdlo5'), 'sxdlo5');
    });

    test('丢掉解释和空格', () {
      expect(parseCaptchaGuess('The captcha is Sx dl o5.'), 'sxdlo5');
    });

    test('取多行里像验证码的那一行', () {
      expect(parseCaptchaGuess('I see the image.\nabc12\n'), 'abc12');
    });

    test('过短或过长返回 null', () {
      expect(parseCaptchaGuess('ab'), isNull);
      expect(parseCaptchaGuess('abcdefghijk'), isNull);
      expect(parseCaptchaGuess(''), isNull);
    });
  });
}
