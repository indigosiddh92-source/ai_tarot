# AI Tarot - MVP 0.1

Приложение для Android: вы задаёте вопрос, выбираете человека, фотографируете
расклад Таро - AI распознаёт карты и даёт символическую интерпретацию
в контексте вашего вопроса.

Это инструмент саморефлексии, а не предсказание будущего.

**Статус: Этап 1 из 8.** Готов скелет проекта: структура, тема, модели,
контракты сервисов, конфигурация ключа, сборка APK в GitHub Actions.
Экраны, локальное хранение, камера и вызовы AI появляются на Этапах 2-6.

---

## 1. Что делает приложение

Главный сценарий:

```
вопрос -> выбор человека -> фото расклада -> распознавание карт -> интерпретация
```

Все данные (люди и их описания) хранятся только на устройстве.
Нет регистрации, нет сервера, нет Firebase, нет платежей.

---

## 2. Как установить Flutter

1. Скачайте Flutter SDK: https://docs.flutter.dev/get-started/install
2. Распакуйте и добавьте папку `flutter/bin` в PATH.
3. Установите Android Studio (он принесёт Android SDK и Java).
4. Проверьте, что всё на месте:

```bash
flutter doctor
```

Все пункты про Android должны быть зелёными. Строки про iOS/Xcode
можно игнорировать.

> Ничего не устанавливать не обязательно, если вы собираете APK только
> через GitHub Actions (раздел 7). Тогда всю работу делает GitHub.

---

## 3. Как установить зависимости

В репозитории лежит только код (`lib/`, `pubspec.yaml`, тесты, workflow).
Платформенная папка `android/` генерируется одной командой:

```bash
bash tool/prepare_android.sh   # создаст android/ и пропишет com.aitarot.app
flutter pub get               # скачает зависимости
```

Скрипт безопасно запускать сколько угодно раз: если `android/` уже есть,
он только проверит конфигурацию и ничего не сломает.

Зависимости проекта:

| Пакет | Зачем |
|-------|-------|
| `http` | запросы к AI API |
| `shared_preferences` | локальное хранение людей (без SQL) |
| `image_picker` | камера и галерея |
| `intl` | форматирование дат |
| `flutter_lints` | проверка кода (только разработка) |

---

## 4. Куда добавить API key

**Ключа нет в коде и не должно быть в репозитории.** Он передаётся
снаружи во время сборки и читается в `lib/config/app_config.dart`.

### Вариант А: локальная разработка

Скопируйте шаблон и впишите ключ:

```bash
cp dart_define.example.json dart_define.dev.json
```

```json
{
  "AI_API_KEY": "ваш-ключ-AnyModel",
  "AI_BASE_URL": "https://anymodel.org/v1",
  "AI_VISION_MODEL": "am/llama-3.2-11b-vision-instruct"
}
```

Файл `dart_define.dev.json` уже в `.gitignore` - в git он не попадёт.

### Вариант Б: GitHub Actions Secret

В репозитории: **Settings -> Secrets and variables -> Actions -> New repository secret**

* Name: `ANYMODEL_API_KEY`
* Secret: ваш ключ AnyModel

Workflow передаёт его в сборку как `--dart-define=AI_API_KEY=...`.
`AI_BASE_URL` (`https://anymodel.org/v1`) и `AI_VISION_MODEL`
(`am/llama-3.2-11b-vision-instruct`) заданы прямо в
`.github/workflows/build_apk.yml`. Repository Variables больше не используются:
старые значения там ничего не переопределят.

### Вариант В: переменная окружения

```bash
flutter run --dart-define=AI_API_KEY="$AI_API_KEY"
```

Если ключ не задан, приложение запустится, но честно напишет
**«AI API не настроен»**. Фальшивых интерпретаций не будет.

---

## 5. Как запустить

Подключите телефон с включённой отладкой по USB или запустите эмулятор:

```bash
flutter run --dart-define-from-file=dart_define.dev.json
```

Проверки без устройства:

```bash
flutter analyze   # статический анализ, должно быть "No issues found!"
flutter test      # смок-тест главного экрана
```

---

## 6. Как собрать APK

```bash
flutter build apk --release --dart-define-from-file=dart_define.dev.json
```

Готовый файл: `build/app/outputs/flutter-apk/app-release.apk`

Перекиньте его на телефон и установите, разрешив установку из
неизвестных источников. APK подписан отладочным ключом: для MVP это
нормально, для Google Play потребуется свой keystore.

---

## 7. Как настроить GitHub Actions

1. Создайте пустой репозиторий на GitHub.
2. Залейте в него содержимое этого архива (ветка `main`).
3. Добавьте secret `ANYMODEL_API_KEY` (раздел 4, вариант Б).
4. Откройте вкладку **Actions** -> **Build APK** -> **Run workflow**.
5. Когда сборка закончится, скачайте артефакт **ai-tarot-apk**
   внизу страницы запуска.

Workflow запускается вручную (`workflow_dispatch`), на push в `main`
и на pull request. Шаги: checkout -> Java 17 -> Flutter stable ->
`tool/prepare_android.sh` -> `flutter pub get` -> `flutter analyze` ->
`flutter test` -> `flutter build apk --release` -> загрузка артефакта.

Файл: `.github/workflows/build_apk.yml`

---

## 8. Где заменить AI-провайдера

Два интерфейса, от которых зависит UI:

* `lib/services/vision_service.dart` - фото -> список карт
* `lib/services/tarot_ai_service.dart` - вопрос + человек + карты -> текст

Чтобы сменить провайдера, напишите новый класс, реализующий эти
интерфейсы, и поменяйте URL/модели в `lib/config/app_config.dart`.
Экраны править не нужно.

Ожидаемый ответ Vision-модели:

```json
{
  "cards": [
    { "name": "The Fool", "orientation": "upright" },
    { "name": "The Lovers", "orientation": "reversed" }
  ]
}
```

---

## Структура проекта

```
ai_tarot/
├── .github/workflows/build_apk.yml   сборка APK в GitHub Actions
├── tool/
│   ├── prepare_android.sh            генерация android/ + com.aitarot.app
│   └── prepare_android.py
├── lib/
│   ├── main.dart
│   ├── config/
│   │   ├── app_config.dart           ключ и модели (без секретов в коде)
│   │   └── app_theme.dart            тёмная тема Material 3
│   ├── models/
│   │   ├── person.dart
│   │   ├── tarot_card.dart
│   │   └── tarot_reading.dart
│   ├── services/
│   │   ├── storage_service.dart      контракт локального хранилища
│   │   ├── vision_service.dart       контракт распознавания карт
│   │   └── tarot_ai_service.dart     контракт интерпретации
│   ├── screens/
│   │   └── home_screen.dart          главный экран / вопрос
│   ├── widgets/
│   │   └── config_banner.dart        статус настроек AI
│   └── utils/
│       └── app_exceptions.dart       понятные пользователю ошибки
├── test/smoke_test.dart
├── dart_define.example.json
├── pubspec.yaml
└── analysis_options.yaml
```

---

## План работ

| Этап | Содержание | Статус |
|------|------------|--------|
| 1 | Структура, конфиг, тема, CI | готово |
| 2 | Все экраны и навигация | далее |
| 3 | Локальное хранение людей | |
| 4 | Камера и галерея | |
| 5 | Vision API | |
| 6 | Tarot AI API | |
| 7 | Обработка ошибок | |
| 8 | Финальная сборка APK | |
