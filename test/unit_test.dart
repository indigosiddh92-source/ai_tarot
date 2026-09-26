import 'dart:convert';

import 'package:ai_tarot/models/tarot_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CardOrientation.fromApi', () {
    test('parses upright', () {
      expect(CardOrientation.fromApi('upright'), CardOrientation.upright);
      expect(CardOrientation.fromApi('UPRIGHT'), CardOrientation.upright);
      expect(CardOrientation.fromApi('  Upright  '), CardOrientation.upright);
    });

    test('parses reversed', () {
      expect(CardOrientation.fromApi('reversed'), CardOrientation.reversed);
      expect(CardOrientation.fromApi('REVERSED'), CardOrientation.reversed);
      expect(CardOrientation.fromApi(' Reversed '), CardOrientation.reversed);
    });

    test('parses unknown as unknown, never as upright', () {
      expect(CardOrientation.fromApi('unknown'), CardOrientation.unknown);
      expect(CardOrientation.fromApi('UNKNOWN'), CardOrientation.unknown);
      expect(CardOrientation.fromApi('unknown'), isNot(CardOrientation.upright));
    });

    test('never guesses orientation for missing or garbage values', () {
      expect(CardOrientation.fromApi(null), CardOrientation.unknown);
      expect(CardOrientation.fromApi(''), CardOrientation.unknown);
      expect(CardOrientation.fromApi('   '), CardOrientation.unknown);
      expect(CardOrientation.fromApi('sideways'), CardOrientation.unknown);
    });

    test('enum exposes exactly three states', () {
      expect(CardOrientation.values, hasLength(3));
      expect(
        CardOrientation.values.map((CardOrientation o) => o.apiValue),
        containsAll(<String>['upright', 'reversed', 'unknown']),
      );
    });

    test('isKnown is false only for unknown', () {
      expect(CardOrientation.upright.isKnown, isTrue);
      expect(CardOrientation.reversed.isKnown, isTrue);
      expect(CardOrientation.unknown.isKnown, isFalse);
    });

    test('unknown has a human readable label', () {
      expect(CardOrientation.unknown.label, 'Ориентация не определена');
      expect(CardOrientation.upright.label, 'прямая');
      expect(CardOrientation.reversed.label, 'перевёрнутая');
    });
  });

  group('TarotCard.fromJson', () {
    test('parses upright card', () {
      final TarotCard card = TarotCard.fromJson(<String, dynamic>{
        'name': 'The Magician',
        'orientation': 'upright',
        'position': 1,
      });

      expect(card.name, 'The Magician');
      expect(card.orientation, CardOrientation.upright);
      expect(card.position, 1);
      expect(card.isRecognized, isTrue);
    });

    test('parses reversed card', () {
      final TarotCard card = TarotCard.fromJson(<String, dynamic>{
        'name': 'The Lovers',
        'orientation': 'reversed',
        'position': 2,
      });

      expect(card.orientation, CardOrientation.reversed);
      expect(card.isRecognized, isTrue);
    });

    test('keeps unknown orientation on a recognized card', () {
      final TarotCard card = TarotCard.fromJson(<String, dynamic>{
        'name': 'The Tower',
        'orientation': 'unknown',
        'position': 3,
      });

      // Карта опознана, а ориентация - нет. Оба факта сохраняются.
      expect(card.name, 'The Tower');
      expect(card.orientation, CardOrientation.unknown);
      expect(card.orientation.isKnown, isFalse);
      expect(card.isRecognized, isTrue);
    });

    test('keeps unknown orientation when field is absent', () {
      final TarotCard card = TarotCard.fromJson(<String, dynamic>{
        'name': 'The Star',
        'position': 1,
      });

      expect(card.orientation, CardOrientation.unknown);
    });

    test('marks unknown card name as not recognized', () {
      final TarotCard card = TarotCard.fromJson(<String, dynamic>{
        'name': 'unknown',
        'orientation': 'unknown',
        'position': 1,
      });

      expect(card.isRecognized, isFalse);
      expect(card.orientation, CardOrientation.unknown);
    });
  });

  group('TarotCard.toJson', () {
    test('round-trips all three orientations', () {
      for (final CardOrientation orientation in CardOrientation.values) {
        final TarotCard original = TarotCard(
          name: 'The Fool',
          orientation: orientation,
          position: 1,
        );

        final TarotCard restored = TarotCard.fromJson(original.toJson());

        expect(restored.orientation, orientation);
        expect(restored.name, original.name);
        expect(restored.position, original.position);
      }
    });

    test('serializes unknown as "unknown"', () {
      const TarotCard card = TarotCard(
        name: 'The Fool',
        orientation: CardOrientation.unknown,
      );

      expect(card.toJson()['orientation'], 'unknown');
      expect(card.toJson().containsKey('position'), isFalse);
    });
  });

  group('Vision JSON payload -> TarotCard', () {
    test('parses a mixed spread and preserves order and unknown', () {
      // Такой JSON приходит внутри candidates[0].content.parts[0].text
      const String payload = '''
{"cards":[
  {"name":"The Fool","orientation":"upright","position":1},
  {"name":"Three of Cups","orientation":"reversed","position":2},
  {"name":"The Hermit","orientation":"unknown","position":3},
  {"name":"unknown","orientation":"unknown","position":4}
]}''';

      final Map<String, dynamic> parsed =
          jsonDecode(payload) as Map<String, dynamic>;
      final List<TarotCard> cards = (parsed['cards'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(TarotCard.fromJson)
          .toList();

      expect(cards, hasLength(4));

      expect(cards[0].orientation, CardOrientation.upright);
      expect(cards[1].orientation, CardOrientation.reversed);
      expect(cards[2].orientation, CardOrientation.unknown);
      expect(cards[3].orientation, CardOrientation.unknown);

      // Ни одна unknown-ориентация не превратилась в upright.
      expect(
        cards.where((TarotCard c) => c.orientation == CardOrientation.upright),
        hasLength(1),
      );

      // Порядок карт сохранён.
      expect(
        cards.map((TarotCard c) => c.position),
        <int>[1, 2, 3, 4],
      );

      // Нераспознанное имя не мешает остальным данным.
      expect(cards[3].isRecognized, isFalse);
      expect(cards[2].isRecognized, isTrue);
    });
  });
}
