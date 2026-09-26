/// Конфигурационный слой приложения.
///
/// Ключ НИКОГДА не хранится в исходном коде. Он приходит извне, через
/// `--dart-define` (или `--dart-define-from-file`), поэтому в репозитории
/// секрета нет.
///
/// Локальная разработка:
///   flutter run --dart-define-from-file=dart_define.dev.json
///
/// GitHub Actions (секрет ANYMODEL_API_KEY -> AI_API_KEY):
///   flutter build apk --release --dart-define=AI_API_KEY=<secret>
class AppConfig {
  const AppConfig._();

  /// Значения по умолчанию для AI Vision (AnyModel, OpenAI-compatible API).
  static const String defaultBaseUrl = 'https://anymodel.org/v1';
  static const String defaultVisionModel = 'am/llama-3.2-11b-vision-instruct';

  /// Ключ AnyModel API. Пустая строка = провайдер не настроен.
  /// Передаётся в HTTP-заголовке `Authorization: Bearer <key>`.
  static const String apiKey = String.fromEnvironment('AI_API_KEY');

  /// Базовый URL OpenAI-compatible API.
  /// Итоговый запрос: POST {baseUrl}/chat/completions
  static const String baseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: defaultBaseUrl,
  );

  /// Vision-модель, распознающая карты на фотографии.
  /// Единственное место в проекте, где задаётся model ID.
  static const String visionModel = String.fromEnvironment(
    'AI_VISION_MODEL',
    defaultValue: defaultVisionModel,
  );

  /// Просить ли у API `response_format: {"type": "json_object"}`.
  ///
  /// По умолчанию выключено: не каждая модель/провайдер за
  /// OpenAI-compatible endpoint поддерживает JSON mode, и неподдерживаемый
  /// параметр может превратить рабочий запрос в HTTP 400. Без него формат
  /// задаётся строгой инструкцией в prompt + устойчивым парсингом.
  /// Включить: --dart-define=AI_VISION_JSON_MODE=true
  static const bool visionJsonMode = bool.fromEnvironment(
    'AI_VISION_JSON_MODE',
    defaultValue: false,
  );

  /// Максимальный размер изображения, отправляемого в Vision API.
  static const int maxImageBytes = 4 * 1024 * 1024;

  /// Таймаут одного запроса к AI.
  static const Duration requestTimeout = Duration(seconds: 60);

  /// Настроен ли AI. Если false - UI обязан сказать об этом честно
  /// и не притворяться, что распознавание настоящее.
  static bool get isAiConfigured => apiKey.trim().isNotEmpty;
}
