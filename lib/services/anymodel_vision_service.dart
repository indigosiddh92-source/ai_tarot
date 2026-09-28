import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/tarot_card.dart';
import '../utils/app_exceptions.dart';
import 'vision_service.dart';

/// Распознавание Tarot-карт через AnyModel (OpenAI-compatible API).
///
/// Endpoint:  POST {baseUrl}/chat/completions
/// Auth:      Authorization: Bearer <AI_API_KEY>
/// Модель:    AppConfig.visionModel (по умолчанию am/llama-3.2-11b-vision-instruct)
/// Фото:      data:image/jpeg;base64,... внутри messages[].content[].image_url
///
/// Ключ передаётся ТОЛЬКО в заголовке. Он не попадает в URL, логи,
/// тексты ошибок и UI. Тело запроса и сырой ответ не логируются.
class AnyModelVisionService implements VisionService {
  AnyModelVisionService({
    http.Client? client,
    String? apiKey,
    String? baseUrl,
    String? model,
    bool? jsonMode,
    Duration? timeout,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey ?? AppConfig.apiKey,
        _baseUrl = baseUrl ?? AppConfig.baseUrl,
        _model = model ?? AppConfig.visionModel,
        _jsonMode = jsonMode ?? AppConfig.visionJsonMode,
        _timeout = timeout ?? AppConfig.requestTimeout;

  final http.Client _client;
  final String _apiKey;
  final String _baseUrl;
  final String _model;
  final bool _jsonMode;
  final Duration _timeout;

  /// Model ID, который уйдёт в запрос.
  String get model => _model;

  /// Полный endpoint: {baseUrl}/chat/completions. Ключа в URL нет.
  Uri get endpoint {
    final String base = _baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/chat/completions');
  }

  bool get _isConfigured => _apiKey.trim().isNotEmpty;

  /// Безопасное debug-логирование: только model, HTTP status, размер фото,
  /// число карт. Ни ключа, ни тела запроса, ни ответа.
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[AnyModelVisionService] $message');
    }
  }

  @override
  Future<List<TarotCard>> recognizeCards(Uint8List imageBytes) async {
    if (!_isConfigured) {
      throw const AiNotConfiguredException();
    }
    if (imageBytes.isEmpty) {
      throw const AppException('Изображение пусто. Сделайте снимок заново.');
    }
    if (imageBytes.lengthInBytes > AppConfig.maxImageBytes) {
      throw const ImageTooLargeException();
    }

    try {
      final String body = jsonEncode(buildRequestBody(imageBytes));

      _log('model=$_model');
      _log('image=${imageBytes.lengthInBytes} bytes');

      final http.Response response = await _client
          .post(
            endpoint,
            headers: <String, String>{
              'Authorization': 'Bearer ${_apiKey.trim()}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(_timeout);

      _log('HTTP ${response.statusCode}');
      throwForStatus(response.statusCode);

      final List<TarotCard> cards =
          parseCompletion(utf8.decode(response.bodyBytes));
      _log('cards=${cards.length}');
      return cards;
    } on AppException {
      rethrow;
    } on TimeoutException {
      _log('timeout');
      throw const ApiTimeoutException();
    } on SocketException {
      _log('no network');
      throw const NoInternetException();
    } on HandshakeException {
      _log('tls handshake failed');
      throw const NoInternetException();
    } on http.ClientException {
      _log('http client error');
      throw const NoInternetException();
    } catch (error) {
      // Текст исключения не показываем и не логируем.
      _log('unexpected ${error.runtimeType}');
      throw const ApiException(
        'Не удалось распознать карты.\nПопробуйте ещё раз.',
      );
    }
  }

  /// Тело запроса в OpenAI-compatible формате.
  ///
  /// Всё в одном user-сообщении (текст + картинка), без system-роли:
  /// часть провайдеров Llama 3.2 Vision не принимает system prompt
  /// вместе с изображением.
  @visibleForTesting
  Map<String, dynamic> buildRequestBody(Uint8List imageBytes) {
    return <String, dynamic>{
      'model': _model,
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'user',
          'content': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': visionPrompt},
            <String, dynamic>{
              'type': 'image_url',
              'image_url': <String, String>{
                'url': 'data:image/jpeg;base64,${base64Encode(imageBytes)}',
              },
            },
          ],
        },
      ],
      'temperature': 0,
      'max_tokens': 1024,
      'stream': false,
      if (_jsonMode)
        'response_format': <String, String>{'type': 'json_object'},
    };
  }

  /// HTTP-статус -> понятная пользователю ошибка. Тело ответа не читается.
  @visibleForTesting
  static void throwForStatus(int code) {
    if (code >= 200 && code < 300) return;
    switch (code) {
      case 400:
        throw const AiBadRequestException();
      case 401:
      case 403:
        throw const InvalidApiKeyException();
      case 402:
        throw const AiPaymentRequiredException();
      case 404:
        throw const AiModelNotFoundException();
      case 408:
        throw const ApiTimeoutException();
      case 429:
        throw const AiRateLimitException();
    }
    if (code >= 500 && code < 600) {
      throw const AiServerException();
    }
    throw const ApiException(
      'AI вернул неожиданный ответ.\nПопробуйте ещё раз.',
    );
  }

  /// Разбор ответа /chat/completions:
  /// choices[0].message.content -> JSON {"cards": [...]} -> List<TarotCard>.
  ///
  /// TarotCard.fromJson и CardOrientation.fromApi остаются источником
  /// истины: здесь только приводятся типы полей, ничего не угадывается.
  @visibleForTesting
  static List<TarotCard> parseCompletion(String responseBody) {
    final Object? envelope = _tryDecode(responseBody);
    if (envelope is! Map<String, dynamic>) {
      throw const AiInvalidResponseException();
    }

    final Object? choices = envelope['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiInvalidResponseException();
    }

    final Object? first = choices.first;
    final Object? message = first is Map<String, dynamic> ? first['message'] : null;
    if (message is! Map<String, dynamic>) {
      throw const AiInvalidResponseException();
    }

    final String content = _contentToText(message['content']).trim();
    if (content.isEmpty) {
      throw const AiInvalidResponseException();
    }

    final Object? payload = extractJson(content);
    final Object? cardsJson;
    if (payload is Map<String, dynamic>) {
      cardsJson = payload['cards'];
    } else if (payload is List) {
      // Модель вернула голый массив карт - принимаем как cards.
      cardsJson = payload;
    } else {
      cardsJson = null;
    }

    if (cardsJson is! List) {
      throw const AiInvalidResponseException();
    }

    final List<TarotCard> cards = cardsJson
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> raw) => TarotCard.fromJson(_normalize(raw)))
        .toList();

    if (cards.isEmpty) {
      throw const NoCardsFoundException();
    }

    // Порядок по физической позиции, если она есть у всех карт.
    // Номера позиций не меняются: нераспознанная карта на месте 3
    // остаётся картой №3.
    if (cards.every((TarotCard c) => c.position != null)) {
      cards.sort((TarotCard a, TarotCard b) => a.position!.compareTo(b.position!));
    }

    return cards;
  }

  /// Достаёт JSON из текста модели: чистый JSON, блок ```json ... ```,
  /// или первый {...} / [...] внутри текста. null, если JSON нет.
  @visibleForTesting
  static Object? extractJson(String text) {
    final String trimmed = text.trim();

    final Object? direct = _tryDecode(trimmed);
    if (direct != null) return direct;

    final RegExpMatch? fenced =
        RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false)
            .firstMatch(trimmed);
    if (fenced != null) {
      final Object? inFence = _tryDecode(fenced.group(1)!.trim());
      if (inFence != null) return inFence;
    }

    for (final List<String> pair in <List<String>>[
      <String>['{', '}'],
      <String>['[', ']'],
    ]) {
      final int start = trimmed.indexOf(pair[0]);
      final int end = trimmed.lastIndexOf(pair[1]);
      if (start >= 0 && end > start) {
        final Object? sliced = _tryDecode(trimmed.substring(start, end + 1));
        if (sliced != null) return sliced;
      }
    }
    return null;
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  /// content бывает строкой (стандарт) или списком частей
  /// [{"type":"text","text":"..."}] у некоторых провайдеров.
  static String _contentToText(Object? content) {
    if (content is String) return content;
    if (content is List) {
      final StringBuffer buffer = StringBuffer();
      for (final Object? part in content) {
        if (part is Map && part['text'] is String) {
          buffer.write(part['text'] as String);
        } else if (part is String) {
          buffer.write(part);
        }
      }
      return buffer.toString();
    }
    return '';
  }

  /// Приводит типы полей к тому, что ожидает TarotCard.fromJson.
  /// Пустое/отсутствующее имя -> "unknown" (карта не удаляется).
  /// orientation передаётся как есть: fromApi сам сделает unknown.
  static Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    final Object? name = raw['name'];
    final Object? orientation = raw['orientation'];
    final Object? position = raw['position'];

    int? pos;
    if (position is int) {
      pos = position;
    } else if (position is num && position == position.roundToDouble()) {
      pos = position.toInt();
    } else if (position is String) {
      pos = int.tryParse(position.trim());
    }

    final String cleanName = name is String ? name.trim() : '';

    return <String, dynamic>{
      'name': cleanName.isEmpty ? 'unknown' : cleanName,
      'orientation': orientation is String ? orientation : null,
      if (pos != null) 'position': pos,
    };
  }

  /// Prompt сохраняет смысл Stage 4A.2 и дополнительно жёстко задаёт
  /// формат ответа, т.к. structured output по умолчанию не используется.
  @visibleForTesting
  static const String visionPrompt =
      '''You are analyzing a photograph of a physical Tarot card spread.
Find every Tarot card that is actually visible in the image.

For each visible card return three fields.

1. name
   The exact card name using standard Tarot deck naming,
   for example "The Fool", "Three of Cups", "Queen of Swords".
   If you cannot identify the card confidently, set name to "unknown".

2. orientation
   Judge the orientation relative to the photograph itself, not to the table.
   - "upright"   the card artwork appears in its normal orientation
   - "reversed"  the card artwork is rotated 180 degrees (upside down)
   - "unknown"   the orientation cannot be determined with confidence
   Never guess the orientation. If there is any doubt, return "unknown".
   Do not assume "upright" as a default.

3. position
   The physical position of the card in the spread, starting at 1.
   One row: number the cards left to right.
   Several rows: top row first, left to right, then the next row.
   Every visible card keeps its physical position, including unrecognized
   cards. Never skip, remove or renumber cards because one is unknown.
   Example: if the third card from the left cannot be identified, return
   {"name": "unknown", "orientation": "unknown", "position": 3}.

Strict rules:
- Never invent cards that are not visible in the image.
- Report every visible card, even if its name is "unknown".
- If the image contains no Tarot cards at all, return {"cards": []}.

Output format:
Respond with ONLY one JSON object, no markdown, no code fences, no comments,
no explanation before or after it. Use exactly this structure:
{"cards": [{"name": "The Magician", "orientation": "upright", "position": 1}]}
Allowed orientation values: "upright", "reversed", "unknown".''';
}
