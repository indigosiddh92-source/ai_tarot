import 'tarot_card.dart';

/// Состояние распознавания расклада целиком.
enum RecognitionState {
  /// Все карты на фотографии распознаны.
  complete,

  /// Часть карт распознана, часть - нет.
  partial,

  /// Карты найдены, но ни одну не удалось определить.
  nothingRecognized,

  /// Карт на фотографии не найдено вообще.
  empty,
}

/// Карта вместе с её позицией в раскладе.
///
/// Позиция берётся из `TarotCard.position` (её присылает Gemini), а если
/// её нет - из фактического порядка в списке. Порядок карт никогда не
/// пересобирается заново, только читается.
class PositionedCard {
  const PositionedCard({required this.card, required this.position});

  final TarotCard card;

  /// Номер карты в раскладе, начиная с 1.
  final int position;

  /// Текст для UI. Для нераспознанной карты техническое `unknown`
  /// пользователю не показывается.
  String get displayName =>
      card.isRecognized ? card.name : 'Карта №$position — не распознана';
}

/// Разбор результата Vision API на «распознано» и «не распознано».
///
/// Нераспознанная карта (`name == "unknown"`) - это НЕ ошибка API,
/// а нормальное состояние расклада, которое нужно честно показать.
class RecognitionSummary {
  const RecognitionSummary({
    required this.cards,
    required this.recognized,
    required this.unrecognized,
  });

  /// Все карты в исходном порядке.
  final List<PositionedCard> cards;

  /// Только распознанные карты, порядок сохранён.
  final List<PositionedCard> recognized;

  /// Только нераспознанные карты, порядок сохранён.
  final List<PositionedCard> unrecognized;

  factory RecognitionSummary.fromCards(List<TarotCard> source) {
    final List<PositionedCard> positioned = <PositionedCard>[];

    for (int i = 0; i < source.length; i++) {
      final TarotCard card = source[i];
      positioned.add(
        PositionedCard(card: card, position: card.position ?? i + 1),
      );
    }

    return RecognitionSummary(
      cards: List<PositionedCard>.unmodifiable(positioned),
      recognized: List<PositionedCard>.unmodifiable(
        positioned.where((PositionedCard p) => p.card.isRecognized),
      ),
      unrecognized: List<PositionedCard>.unmodifiable(
        positioned.where((PositionedCard p) => !p.card.isRecognized),
      ),
    );
  }

  int get totalCount => cards.length;
  int get recognizedCount => recognized.length;
  int get unrecognizedCount => unrecognized.length;

  bool get hasCards => cards.isNotEmpty;
  bool get hasUnrecognized => unrecognized.isNotEmpty;
  bool get hasRecognized => recognized.isNotEmpty;

  RecognitionState get state {
    if (cards.isEmpty) return RecognitionState.empty;
    if (unrecognized.isEmpty) return RecognitionState.complete;
    if (recognized.isEmpty) return RecognitionState.nothingRecognized;
    return RecognitionState.partial;
  }

  /// «Не удалось определить 1 карту» / «2 карты» / «5 карт».
  /// Пустая строка, если все карты распознаны.
  String get unrecognizedMessage {
    if (unrecognized.isEmpty) return '';
    return 'Не удалось определить $unrecognizedCount '
        '${_cardWordAccusative(unrecognizedCount)}';
  }

  /// Позиции нераспознанных карт для списка в UI.
  List<String> get unrecognizedLabels =>
      unrecognized.map((PositionedCard p) => p.displayName).toList();

  static String _cardWordAccusative(int count) {
    final int mod100 = count % 100;
    final int mod10 = count % 10;

    if (mod10 == 1 && mod100 != 11) return 'карту';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'карты';
    }
    return 'карт';
  }
}
