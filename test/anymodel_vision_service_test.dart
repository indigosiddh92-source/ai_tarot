import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_tarot/config/app_config.dart';
import 'package:ai_tarot/models/tarot_card.dart';
import 'package:ai_tarot/services/anymodel_vision_service.dart';
import 'package:ai_tarot/utils/app_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Реальных запросов к AnyModel нет: HTTP подменяется MockClient.
/// Ключ ниже фиктивный и существует только внутри тестов.
const String _fakeKey = 'test-key-not-real';
final Uint8List _jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xD9]);

/// Оборачивает content модели в стандартный ответ /chat/completions.
String _completion(Object? content) => jsonEncode(<String, dynamic>{
      'id': 'chatcmpl-test',
      'object': 'chat.completion',
      'choices': <Map<String, dynamic>>[
        <String, dynamic>{
          'index': 0,
          'message': <String, dynamic>{'role': 'assistant', 'content': content},
          'finish_reason': 'stop',
        },
      ],
    });

AnyModelVisionService _service(
  MockClient client, {
  String apiKey = _fakeKey,
}) =>
    AnyModelVisionService(
      client: client,
      apiKey: apiKey,
      baseUrl: AppConfig.defaultBaseUrl,
      model: AppConfig.defaultVisionModel,
    );

MockClient _respond(int status, String body) =>
    MockClient((http.Request _) async => http.Response(body, status));

void main() {
  group('Конфигурация', () {
    test('endpoint = https://anymodel.org/v1/chat/completions', () {
      final AnyModelVisionService s = _service(_respond(200, ''));
      expect(
        s.endpoint.toString(),
        'https://anymodel.org/v1/chat/completions',
      );
    });

    test('хвостовой слэш в base URL не ломает endpoint', () {
      final AnyModelVisionService s = AnyModelVisionService(
        client: _respond(200, ''),
        apiKey: _fakeKey,
        baseUrl: 'https://anymodel.org/v1/',
      );
      expect(
        s.endpoint.toString(),
        'https://anymodel.org/v1/chat/completions',
      );
    });

    test('model ID по умолчанию', () {
      expect(AppConfig.defaultVisionModel, 'am/llama-3.2-11b-vision-instruct');
      expect(AppConfig.defaultBaseUrl, 'https://anymodel.org/v1');
      expect(_service(_respond(200, '')).model,
          'am/llama-3.2-11b-vision-instruct');
    });

    test('нет API key -> AiNotConfiguredException, запрос не отправляется',
        () async {
      bool called = false;
      final MockClient client = MockClient((http.Request _) async {
        called = true;
        return http.Response('', 200);
      });

      await expectLater(
        _service(client, apiKey: '').recognizeCards(_jpeg),
        throwsA(isA<AiNotConfiguredException>()),
      );
      await expectLater(
        _service(client, apiKey: '   ').recognizeCards(_jpeg),
        throwsA(isA<AiNotConfiguredException>()),
      );
      expect(called, isFalse);
    });
  });

  group('HTTP-запрос', () {
    test('POST, Bearer-ключ в заголовке, ключа нет в URL', () async {
      late http.Request captured;
      final MockClient client = MockClient((http.Request request) async {
        captured = request;
        return http.Response(
          _completion('{"cards":[{"name":"The Fool",'
              '"orientation":"upright","position":1}]}'),
          200,
        );
      });

      await _service(client).recognizeCards(_jpeg);

      expect(captured.method, 'POST');
      expect(captured.url.toString(),
          'https://anymodel.org/v1/chat/completions');
      expect(captured.url.toString(), isNot(contains(_fakeKey)));
      expect(captured.headers['Authorization'], 'Bearer $_fakeKey');
    });

    test('тело: model + messages + text + data URL картинки', () {
      final Map<String, dynamic> body =
          _service(_respond(200, '')).buildRequestBody(_jpeg);

      expect(body['model'], 'am/llama-3.2-11b-vision-instruct');
      expect(body.containsKey('contents'), isFalse, reason: 'не Gemini');
      expect(body.containsKey('response_format'), isFalse,
          reason: 'JSON mode выключен по умолчанию');

      final List<dynamic> messages = body['messages'] as List<dynamic>;
      expect(messages, hasLength(1));
      final Map<String, dynamic> msg = messages.single as Map<String, dynamic>;
      expect(msg['role'], 'user');

      final List<dynamic> content = msg['content'] as List<dynamic>;
      expect((content[0] as Map<String, dynamic>)['type'], 'text');
      final Map<String, dynamic> image = content[1] as Map<String, dynamic>;
      expect(image['type'], 'image_url');
      expect(
        (image['image_url'] as Map<String, dynamic>)['url'],
        'data:image/jpeg;base64,${base64Encode(_jpeg)}',
      );
    });

    test('JSON mode добавляется только при явном включении', () {
      final AnyModelVisionService s = AnyModelVisionService(
        client: _respond(200, ''),
        apiKey: _fakeKey,
        jsonMode: true,
      );
      expect(s.buildRequestBody(_jpeg)['response_format'],
          <String, String>{'type': 'json_object'});
    });

    test('ключ не попадает в тексты ошибок', () async {
      for (final int code in <int>[400, 401, 403, 404, 429, 500]) {
        try {
          await _service(_respond(code, '{"error":"$_fakeKey"}'))
              .recognizeCards(_jpeg);
          fail('ожидалась ошибка для HTTP $code');
        } on AppException catch (e) {
          expect(e.message, isNot(contains(_fakeKey)));
          expect(e.message, isNot(contains('anymodel.org')));
        }
      }
    });
  });

  group('Разбор ответа', () {
    test('нормальный JSON', () {
      final List<TarotCard> cards =
          AnyModelVisionService.parseCompletion(_completion(
        '{"cards":['
        '{"name":"The Magician","orientation":"upright","position":1},'
        '{"name":"The Moon","orientation":"reversed","position":2}]}',
      ));

      expect(cards, hasLength(2));
      expect(cards[0].name, 'The Magician');
      expect(cards[0].orientation, CardOrientation.upright);
      expect(cards[1].orientation, CardOrientation.reversed);
    });

    test('unknown карта остаётся unknown, orientation не становится upright',
        () {
      final List<TarotCard> cards =
          AnyModelVisionService.parseCompletion(_completion(
        '{"cards":['
        '{"name":"The Fool","orientation":"upright","position":1},'
        '{"name":"The Star","orientation":"unknown","position":2},'
        '{"name":"unknown","orientation":"unknown","position":3}]}',
      ));

      expect(cards[1].orientation, CardOrientation.unknown);
      expect(cards[2].orientation, CardOrientation.unknown);
      expect(cards[2].isRecognized, isFalse);
      expect(
        cards.where((TarotCard c) => c.orientation == CardOrientation.upright),
        hasLength(1),
      );
    });

    test('отсутствующая или мусорная orientation -> unknown', () {
      final List<TarotCard> cards =
          AnyModelVisionService.parseCompletion(_completion(
        '{"cards":['
        '{"name":"The Sun","position":1},'
        '{"name":"The Tower","orientation":"sideways","position":2},'
        '{"name":"Death","orientation":null,"position":3}]}',
      ));

      expect(
        cards.map((TarotCard c) => c.orientation),
        everyElement(CardOrientation.unknown),
      );
    });

    test('position сохраняется, нераспознанная карта не перенумеровывается',
        () {
      final List<TarotCard> cards =
          AnyModelVisionService.parseCompletion(_completion(
        '{"cards":['
        '{"name":"The Lovers","orientation":"upright","position":4},'
        '{"name":"unknown","orientation":"unknown","position":3},'
        '{"name":"The Hermit","orientation":"reversed","position":1},'
        '{"name":"Justice","orientation":"upright","position":2}]}',
      ));

      expect(cards.map((TarotCard c) => c.position), <int>[1, 2, 3, 4]);
      expect(cards[2].name, 'unknown');
      expect(cards[2].position, 3);
    });

    test('position строкой или 3.0 приводится к int', () {
      final List<TarotCard> cards =
          AnyModelVisionService.parseCompletion(_completion(
        '{"cards":['
        '{"name":"The Fool","orientation":"upright","position":"1"},'
        '{"name":"The Sun","orientation":"upright","position":2.0}]}',
      ));
      expect(cards.map((TarotCard c) => c.position), <int>[1, 2]);
    });

    test('пустое имя становится unknown, карта не удаляется', () {
      final List<TarotCard> cards =
          AnyModelVisionService.parseCompletion(_completion(
        '{"cards":[{"name":"","orientation":"upright","position":1}]}',
      ));
      expect(cards.single.name, 'unknown');
      expect(cards.single.isRecognized, isFalse);
    });

    test('JSON в ```json блоке и с текстом вокруг', () {
      const String fenced = 'Here you go:\n```json\n'
          '{"cards":[{"name":"The Fool","orientation":"upright","position":1}]}'
          '\n```\nHope this helps!';
      expect(AnyModelVisionService.parseCompletion(_completion(fenced)),
          hasLength(1));

      const String chatty = 'Sure! {"cards":[{"name":"The Fool",'
          '"orientation":"reversed","position":1}]} Let me know.';
      expect(
        AnyModelVisionService.parseCompletion(_completion(chatty))
            .single
            .orientation,
        CardOrientation.reversed,
      );
    });

    test('content списком частей', () {
      final List<TarotCard> cards =
          AnyModelVisionService.parseCompletion(_completion(<dynamic>[
        <String, String>{
          'type': 'text',
          'text': '{"cards":[{"name":"The Fool",'
              '"orientation":"upright","position":1}]}',
        },
      ]));
      expect(cards, hasLength(1));
    });

    test('битый JSON ответа API', () {
      expect(
        () => AnyModelVisionService.parseCompletion('<html>502</html>'),
        throwsA(isA<AiInvalidResponseException>()),
      );
    });

    test('модель вернула не JSON', () {
      expect(
        () => AnyModelVisionService.parseCompletion(
            _completion('I see three tarot cards on the table.')),
        throwsA(isA<AiInvalidResponseException>()),
      );
    });

    test('нет choices / пустые choices', () {
      expect(() => AnyModelVisionService.parseCompletion('{"id":"x"}'),
          throwsA(isA<AiInvalidResponseException>()));
      expect(() => AnyModelVisionService.parseCompletion('{"choices":[]}'),
          throwsA(isA<AiInvalidResponseException>()));
    });

    test('нет message', () {
      expect(
        () => AnyModelVisionService.parseCompletion(
            '{"choices":[{"index":0}]}'),
        throwsA(isA<AiInvalidResponseException>()),
      );
    });

    test('нет content / пустой content', () {
      expect(
        () => AnyModelVisionService.parseCompletion(_completion(null)),
        throwsA(isA<AiInvalidResponseException>()),
      );
      expect(
        () => AnyModelVisionService.parseCompletion(_completion('   ')),
        throwsA(isA<AiInvalidResponseException>()),
      );
    });

    test('нет поля cards', () {
      expect(
        () => AnyModelVisionService.parseCompletion(
            _completion('{"result":"no cards field"}')),
        throwsA(isA<AiInvalidResponseException>()),
      );
    });

    test('пустой список cards -> NoCardsFoundException', () {
      expect(
        () => AnyModelVisionService.parseCompletion(_completion('{"cards":[]}')),
        throwsA(isA<NoCardsFoundException>()),
      );
    });
  });

  group('HTTP status -> ошибка', () {
    Future<void> expectStatus(int code, Matcher matcher) async {
      await expectLater(
        _service(_respond(code, '{"error":{"message":"x"}}'))
            .recognizeCards(_jpeg),
        throwsA(matcher),
      );
    }

    test('400', () => expectStatus(400, isA<AiBadRequestException>()));
    test('401', () => expectStatus(401, isA<InvalidApiKeyException>()));
    test('403', () => expectStatus(403, isA<InvalidApiKeyException>()));
    test('402', () => expectStatus(402, isA<AiPaymentRequiredException>()));
    test('404', () => expectStatus(404, isA<AiModelNotFoundException>()));
    test('408', () => expectStatus(408, isA<ApiTimeoutException>()));
    test('429', () => expectStatus(429, isA<AiRateLimitException>()));
    test('500', () => expectStatus(500, isA<AiServerException>()));
    test('502', () => expectStatus(502, isA<AiServerException>()));
    test('503', () => expectStatus(503, isA<AiServerException>()));
    test('418 -> общий ApiException',
        () => expectStatus(418, isA<ApiException>()));

    test('сетевая ошибка -> NoInternetException', () async {
      final MockClient client = MockClient((http.Request _) async {
        throw http.ClientException('connection failed');
      });
      await expectLater(
        _service(client).recognizeCards(_jpeg),
        throwsA(isA<NoInternetException>()),
      );
    });

    test('таймаут -> ApiTimeoutException', () async {
      final MockClient client = MockClient((http.Request _) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('', 200);
      });
      final AnyModelVisionService s = AnyModelVisionService(
        client: client,
        apiKey: _fakeKey,
        timeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        s.recognizeCards(_jpeg),
        throwsA(isA<ApiTimeoutException>()),
      );
    });
  });
}
