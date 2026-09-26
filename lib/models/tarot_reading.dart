import 'person.dart';
import 'tarot_card.dart';

/// Готовый расклад: вопрос + человек + карты + интерпретация AI.
class TarotReading {
  const TarotReading({
    required this.question,
    required this.person,
    required this.cards,
    required this.interpretation,
    required this.createdAt,
  });

  final String question;
  final Person person;
  final List<TarotCard> cards;

  /// Текст интерпретации, полученный от AI.
  final String interpretation;

  final DateTime createdAt;
}
