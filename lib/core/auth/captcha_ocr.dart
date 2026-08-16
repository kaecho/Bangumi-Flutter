import 'dart:convert';
import 'dart:io';

/// 从识图模型原文抽出验证码 (字母数字 4-8 位)
String? parseCaptchaGuess(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  text = text.replaceAll(RegExp(r'```[a-zA-Z]*'), '').replaceAll('```', '');
  final tokens = [
    for (final m in RegExp(r'[A-Za-z0-9]+').allMatches(text)) m.group(0)!,
  ];
  if (tokens.isEmpty) return null;

  String? best;
  void consider(String source) {
    final cleaned = source.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (cleaned.length < 4 || cleaned.length > 8) return;
    var score = 0;
    if (RegExp(r'[A-Za-z]').hasMatch(cleaned)) score += 1;
    if (RegExp(r'\d').hasMatch(cleaned)) score += 3;
    if (cleaned.length == 5 || cleaned.length == 6) score += 1;
    final bestScore = best == null
        ? -1
        : (RegExp(r'[A-Za-z]').hasMatch(best!) ? 1 : 0) +
              (RegExp(r'\d').hasMatch(best!) ? 3 : 0) +
              ((best!.length == 5 || best!.length == 6) ? 1 : 0);
    if (score >= bestScore) best = cleaned;
  }

  for (final token in tokens) {
    consider(token);
  }
  for (var i = 0; i < tokens.length; i++) {
    var joined = '';
    for (var j = i; j < tokens.length; j++) {
      joined += tokens[j];
      if (joined.length > 8) break;
      consider(joined);
    }
  }
  return best?.toLowerCase();
}



String? _visionApiKey() {
  const defined = String.fromEnvironment('VISION_API_KEY');
  if (defined.isNotEmpty) return defined;
  return Platform.environment['GROK_API_KEY'] ??
      Platform.environment['OPENAI_API_KEY'];
}

String _visionBaseUrl() {
  const defined = String.fromEnvironment('VISION_BASE_URL');
  if (defined.isNotEmpty) return defined;
  return Platform.environment['OPENAI_BASE_URL'] ?? 'https://api.x.ai/v1';
}

String _visionModel() {
  const defined = String.fromEnvironment('VISION_MODEL');
  if (defined.isNotEmpty) return defined;
  return Platform.environment['VISION_MODEL'] ?? 'deepseek-v4-vision';
}

/// 用识图模型读验证码 GIF. 无 key / 失败时返回 null, 不挡手填.
Future<String?> recognizeLoginCaptcha(List<int> bytes) async {
  if (bytes.isEmpty) return null;
  final key = _visionApiKey();
  if (key == null || key.isEmpty) return null;
  final uri = Uri.parse(
    '${_visionBaseUrl().replaceAll(RegExp(r'/$'), '')}/chat/completions',
  );
  final payload = jsonEncode({
    'model': _visionModel(),
    'temperature': 0,
    'max_tokens': 32,
    'messages': [
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text':
                'This is a website login captcha. Read the characters exactly. '
                'Reply with only the captcha text, no spaces, no punctuation, no explanation.',
          },
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/gif;base64,${base64Encode(bytes)}',
            },
          },
        ],
      },
    ],
  });
  final client = HttpClient();
  try {
    final req = await client.postUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(payload));
    final resp = await req.close().timeout(const Duration(seconds: 25));
    final body = await utf8.decodeStream(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
    final json = jsonDecode(body);
    if (json is! Map) return null;
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final message = first['message'];
    if (message is! Map) return null;
    final content = message['content'];
    if (content is! String) return null;
    return parseCaptchaGuess(content);
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
