import 'dart:typed_data';

import '../models/tarot_card.dart';

/// Распознавание карт на фотографии расклада.
///
/// Абстракция специально отделена от провайдера: чтобы сменить AI,
/// достаточно написать новую реализацию этого интерфейса.
/// Реализация появится на Этапе 5.
abstract class VisionService {
  /// Возвращает карты в порядке слева направо.
  ///
  /// Бросает подклассы AppException с готовым для пользователя текстом,
  /// в том числе AiNotConfiguredException, если ключ не задан.
  Future<List<TarotCard>> recognizeCards(Uint8List imageBytes);
}
