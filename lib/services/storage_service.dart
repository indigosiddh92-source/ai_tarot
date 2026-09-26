import '../models/person.dart';

/// Локальное хранилище людей. Никакого сервера и SQL.
///
/// Контракт объявлен отдельно, чтобы реализацию можно было заменить
/// без правки экранов. Реализация на shared_preferences появится на Этапе 3.
abstract class StorageService {
  /// Все сохранённые люди. Профиль «Я» гарантированно присутствует.
  Future<List<Person>> loadPeople();

  /// Создать или обновить человека.
  Future<void> savePerson(Person person);

  /// Удалить человека. Профиль «Я» удалению не подлежит.
  Future<void> deletePerson(String id);
}
