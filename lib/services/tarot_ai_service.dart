import '../models/person.dart';
import '../models/tarot_card.dart';

/// Интерпретация расклада: вопрос + человек + карты -> текст.
///
/// Так же, как и VisionService, сознательно отвязано от провайдера.
/// Реализация появится на Этапе 6.
abstract class TarotAiService {
  Future<String> interpret({
    required String question,
    required Person person,
    required List<TarotCard> cards,
  });
}
