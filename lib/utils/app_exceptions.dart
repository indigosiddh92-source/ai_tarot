/// Ошибки с текстом, готовым к показу пользователю.
/// Технические детали (stack trace, коды, тела ответов) сюда не попадают.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// AI-провайдер не настроен: нет ключа.
class AiNotConfiguredException extends AppException {
  const AiNotConfiguredException()
      : super(
          'AI API не настроен.\n'
          'Добавьте ключ через AI_API_KEY и пересоберите приложение.',
        );
}

class NoInternetException extends AppException {
  const NoInternetException()
      : super('Нет подключения к интернету.\nПроверьте соединение и повторите.');
}

class ApiTimeoutException extends AppException {
  const ApiTimeoutException()
      : super('AI не ответил вовремя.\nПопробуйте ещё раз.');
}

class InvalidApiKeyException extends AppException {
  const InvalidApiKeyException()
      : super('Ключ AI API отклонён.\nПроверьте правильность ключа.');
}

class ApiException extends AppException {
  const ApiException(super.message);
}

// --- Уточнённые ошибки AI-слоя. Все наследуют ApiException, поэтому
// --- существующая обработка в UI (catch AppException) не меняется.

/// HTTP 400: провайдер отклонил запрос (формат, размер фото и т.п.).
class AiBadRequestException extends ApiException {
  const AiBadRequestException()
      : super('AI отклонил запрос.\nПопробуйте сделать другое фото.');
}

/// HTTP 402: нет доступа к модели (например, закончился баланс).
class AiPaymentRequiredException extends ApiException {
  const AiPaymentRequiredException()
      : super('Нет доступа к AI-модели.\nПроверьте баланс и настройки аккаунта.');
}

/// HTTP 404: модель или endpoint не найдены.
class AiModelNotFoundException extends ApiException {
  const AiModelNotFoundException()
      : super('AI-модель недоступна.\nПроверьте настройки приложения.');
}

/// HTTP 429: превышен лимит запросов.
class AiRateLimitException extends ApiException {
  const AiRateLimitException()
      : super('Превышен лимит запросов к AI.\nПопробуйте позже.');
}

/// HTTP 5xx: сервер провайдера недоступен.
class AiServerException extends ApiException {
  const AiServerException()
      : super('Сервер AI временно недоступен.\nПопробуйте позже.');
}

/// Ответ пришёл, но его невозможно разобрать: битый JSON, нет choices,
/// message, content или поля cards.
class AiInvalidResponseException extends ApiException {
  const AiInvalidResponseException()
      : super('AI вернул ответ в неожиданном формате.\nПопробуйте ещё раз.');
}

class ImageTooLargeException extends AppException {
  const ImageTooLargeException()
      : super('Фотография слишком большая.\nСделайте снимок меньшего размера.');
}

class CardsNotRecognizedException extends AppException {
  const CardsNotRecognizedException()
      : super(
          'Не удалось уверенно определить карты на изображении. '
          'Попробуйте сделать фотографию при хорошем освещении, '
          'чтобы все карты были полностью видны.',
        );
}

class NoCardsFoundException extends AppException {
  const NoCardsFoundException()
      : super(
          'На фотографии не найдено ни одной карты.\n'
          'Разложите карты и сфотографируйте их целиком.',
        );
}

class UnknownCardException extends AppException {
  const UnknownCardException()
      : super(
          'Одна или несколько карт не распознаны.\n'
          'Попробуйте переснять расклад крупнее.',
        );
}
