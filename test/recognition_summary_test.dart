import 'dart:convert';

import 'package:ai_tarot/models/recognition_summary.dart';
import 'package:ai_tarot/models/tarot_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// Тесты состояний распознавания расклада.
/// Реальные вызовы AI API здесь НЕ выполняются: используется только
/// тот JSON, который сервис получает внутри candidates[0].content.parts[0].text.
List<TarotCard> _cardsFromPayload(String payload) {
  final Map<String, dynamic> parsed =
      jsonDecode(payload) as Map<String, dynamic>;
  return (parsed['cards'] as List<dynamic>)
      .whereType<Map<String, dynamic>>()
      .map(TarotCard.fromJson)
      .toList();
}

void main() {
  group('Все карты распознаны', () {
    final List<TarotCard> cards = _cardsFromPayload('''
{"cards":[
  {"name":"The Fool","orientation":"upright","position":1},
  {"name":"Three of Cups","orientation":"reversed","position":2},
  {"name":"The Hermit","orientation":"upright","position":3}
]}''');

    test('состояние complete, нераспознанных нет', () {
      final RecognitionSummary summary = RecognitionSummary.fromCards(cards);

      expect(summary.state, RecognitionState.complete);
      expect(summary.totalCount, 3);
      expect(summary.recognizedCount, 3);
      expect(summary.unrecognizedCount, 0);
      expect(summary.hasUnrecognized, isFalse);
      expect(summary.unrecognizedMessage, isEmpty);
      expect(summary.unrecognizedLabels, isEmpty);
    });

    test('порядок карт сохранён', () {
      final RecognitionSummary summary = RecognitionSummary.fromCards(cards);

      expect(
        summary.cards.map((PositionedCard p) => p.position),
        <int>[1, 2, 3],
      );
      expect(
        summary.cards.map((PositionedCard p) => p.card.name),
        <String>['The Fool', 'Three of Cups', 'The Hermit'],
      );
    });
  });

  group('Одна карта не распознана', () {
    final List<TarotCard> cards = _cardsFromPayload('''
{"cards":[
  {"name":"The Fool","orientation":"upright","position":1},
  {"name":"The Star","orientation":"reversed","position":2},
  {"name":"unknown","orientation":"unknown","position":3}
]}''');

    test('состояние partial, счётчики верны', () {
      final RecognitionSummary summary = RecognitionSummary.fromCards(cards);

      expect(summary.state, RecognitionState.partial);
      expect(summary.recognizedCount, 2);
      expect(summary.unrecognizedCount, 1);
      expect(summary.hasRecognized, isTrue);
      expect(summary.hasUnrecognized, isTrue);
    });

    test('сообщение и позиция нераспознанной карты', () {
      final RecognitionSummary summary = RecognitionSummary.fromCards(cards);

      expect(summary.unrecognizedMessage, 'Не удалось определить 1 карту');
      expect(summary.unrecognizedLabels, <String>['Карта №3 — не распознана']);
    });

    test('распознанные карты сохраняют свои позиции', () {
      final RecognitionSummary summary = RecognitionSummary.fromCards(cards);

      expect(
        summary.recognized.map((PositionedCard p) => p.position),
        <int>[1, 2],
      );
    });
  });

  group('Несколько карт не распознано', () {
    final List<TarotCard> cards = _cardsFromPayload('''
{"cards":[
  {"name":"The Fool","orientation":"upright","position":1},
  {"name":"unknown","orientation":"unknown","position":2},
  {"name":"unknown","orientation":"upright","position":3},
  {"name":"The Tower","orientation":"reversed","position":4}
]}''');

    test('состояние partial, два нераспознанных', () {
      final RecognitionSummary summary = RecognitionSummary.fromCards(cards);

      expect(summary.state, RecognitionState.partial);
      expect(summary.unrecognizedCount, 2);
      expect(summary.recognizedCount, 2);
      expect(summary.unrecognizedMessage, 'Не удалось определить 2 карты');
      expect(summary.unrecognizedLabels, <String>[
        'Карта №2 — не распознана',
        'Карта №3 — не распознана',
      ]);
    });
  });

  group('Все карты не распознаны', () {
    final List<TarotCard> cards = _cardsFromPayload('''
{"cards":[
  {"name":"unknown","orientation":"unknown","position":1},
  {"name":"unknown","orientation":"unknown","position":2}
]}''');

    test('состояние nothingRecognized, но карты не выбрасываются', () {
      final RecognitionSummary summary = RecognitionSummary.fromCards(cards);

      expect(summary.state, RecognitionState.nothingRecognized);
      expect(summary.hasCards, isTrue);
      expect(summary.totalCount, 2);
      expect(summary.recognizedCount, 0);
      expect(summary.unrecognizedCount, 2);
      expect(summary.unrecognizedMessage, 'Не удалось определить 2 карты');
    });
  });

  group('Пустой список карт', () {
    test('состояние empty', () {
      final RecognitionSummary summary =
          RecognitionSummary.fromCards(<TarotCard>[]);

      expect(summary.state, RecognitionState.empty);
      expect(summary.hasCards, isFalse);
      expect(summary.totalCount, 0);
      expect(summary.recognizedCount, 0);
      expect(summary.unrecognizedCount, 0);
      expect(summary.unrecognizedMessage, isEmpty);
    });
  });

  group('Подсчёт нераспознанных карт и склонение', () {
    RecognitionSummary summaryWithUnknown(int count) {
      return RecognitionSummary.fromCards(<TarotCard>[
        for (int i = 1; i <= count; i++)
          TarotCard(
            name: 'unknown',
            orientation: CardOrientation.unknown,
            position: i,
          ),
      ]);
    }

    test('1 карту / 2 карты / 5 карт / 11 карт / 21 карту', () {
      expect(summaryWithUnknown(1).unrecognizedMessage,
          'Не удалось определить 1 карту');
      expect(summaryWithUnknown(2).unrecognizedMessage,
          'Не удалось определить 2 карты');
      expect(summaryWithUnknown(5).unrecognizedMessage,
          'Не удалось определить 5 карт');
      expect(summaryWithUnknown(11).unrecognizedMessage,
          'Не удалось определить 11 карт');
      expect(summaryWithUnknown(21).unrecognizedMessage,
          'Не удалось определить 21 карту');
    });

    test('счётчик равен числу карт с name == "unknown"', () {
      for (int n = 0; n <= 6; n++) {
        expect(summaryWithUnknown(n).unrecognizedCount, n);
      }
    });
  });

  group('Позиции без поля position', () {
    test('позиция берётся из фактического порядка в списке', () {
      final List<TarotCard> cards = _cardsFromPayload('''
{"cards":[
  {"name":"The Fool","orientation":"upright"},
  {"name":"unknown","orientation":"unknown"},
  {"name":"The Sun","orientation":"reversed"}
]}''');

      final RecognitionSummary summary = RecognitionSummary.fromCards(cards);

      expect(
        summary.cards.map((PositionedCard p) => p.position),
        <int>[1, 2, 3],
      );
      expect(summary.unrecognizedLabels, <String>['Карта №2 — не распознана']);
    });
  });

  group('Текст для пользователя не содержит технических значений', () {
    test('нераспознанная карта показывается по-русски, без "unknown"', () {
      final RecognitionSummary summary =
          RecognitionSummary.fromCards(<TarotCard>[
        const TarotCard(
          name: 'unknown',
          orientation: CardOrientation.unknown,
          position: 3,
        ),
      ]);

      final PositionedCard card = summary.unrecognized.single;

      expect(card.displayName, 'Карта №3 — не распознана');
      expect(card.displayName.toLowerCase(), isNot(contains('unknown')));
      expect(summary.unrecognizedMessage.toLowerCase(),
          isNot(contains('unknown')));
    });

    test('распознанная карта показывается своим именем', () {
      final RecognitionSummary summary =
          RecognitionSummary.fromCards(<TarotCard>[
        const TarotCard(
          name: 'The Empress',
          orientation: CardOrientation.upright,
          position: 1,
        ),
      ]);

      expect(summary.recognized.single.displayName, 'The Empress');
    });
  });
}
