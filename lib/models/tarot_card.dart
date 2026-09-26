/// Положение карты в раскладе.
///
/// Три полноценных состояния. `unknown` НЕ схлопывается в `upright`:
/// если ориентацию нельзя определить уверенно, приложение обязано
/// честно сказать об этом, а не догадываться.
enum CardOrientation {
  upright('upright', 'прямая'),
  reversed('reversed', 'перевёрнутая'),
  unknown('unknown', 'Ориентация не определена');

  const CardOrientation(this.apiValue, this.label);

  /// Значение, которое использует Vision API.
  final String apiValue;

  /// Текст для UI.
  final String label;

  /// Известна ли ориентация. Удобно для UI и для Этапа 4B.
  bool get isKnown => this != CardOrientation.unknown;

  /// Разбор значения из ответа API.
  ///
  /// Всё, что не является явным `upright`/`reversed` (включая null, пустую
  /// строку, `unknown` и любой неожиданный текст), становится `unknown`.
  /// Предположений об ориентации не делаем.
  static CardOrientation fromApi(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'upright':
        return CardOrientation.upright;
      case 'reversed':
        return CardOrientation.reversed;
      default:
        return CardOrientation.unknown;
    }
  }
}

/// Одна распознанная карта. Формат совпадает с ответом Vision API:
/// {"name": "The Fool", "orientation": "upright"}
class TarotCard {
  const TarotCard({
    required this.name,
    required this.orientation,
    this.position,
  });

  final String name;
  final CardOrientation orientation;

  /// Порядковый номер карты в раскладе (слева направо), если известен.
  final int? position;

  bool get isRecognized {
    final String trimmed = name.trim();
    return trimmed.isNotEmpty && trimmed.toLowerCase() != 'unknown';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'orientation': orientation.apiValue,
        if (position != null) 'position': position,
      };

  factory TarotCard.fromJson(Map<String, dynamic> json) => TarotCard(
        name: (json['name'] as String? ?? '').trim(),
        orientation: CardOrientation.fromApi(json['orientation'] as String?),
        position: json['position'] is int ? json['position'] as int : null,
      );
}
