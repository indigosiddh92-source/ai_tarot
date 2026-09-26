import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/person.dart';
import 'storage_service.dart';

/// Реализация локального хранилища на shared_preferences.
/// Люди хранятся в JSON-списке под ключом 'people'.
class StorageServiceImpl implements StorageService {
  StorageServiceImpl(this._prefs);

  final SharedPreferences _prefs;
  static const String _key = 'people';

  @override
  Future<List<Person>> loadPeople() async {
    final String? json = _prefs.getString(_key);
    if (json == null) {
      // Первый запуск: возвращаем только "Я"
      return [Person.self()];
    }

    try {
      final List<dynamic> data = jsonDecode(json) as List<dynamic>;
      final List<Person> people = data
          .whereType<Map<String, dynamic>>()
          .map(Person.fromJson)
          .toList();

      // Убедимся, что "Я" всегда есть
      if (!people.any((p) => p.isSelf)) {
        people.insert(0, Person.self());
      }

      return people;
    } catch (e) {
      // Повреждённые данные: возвращаем "Я" по умолчанию
      return [Person.self()];
    }
  }

  @override
  Future<void> savePerson(Person person) async {
    final List<Person> people = await loadPeople();
    final int index = people.indexWhere((p) => p.id == person.id);

    if (index >= 0) {
      people[index] = person;
    } else {
      people.add(person);
    }

    final String json = jsonEncode(
      people.map((p) => p.toJson()).toList(),
    );
    await _prefs.setString(_key, json);
  }

  @override
  Future<void> deletePerson(String id) async {
    if (id == Person.selfId) return; // "Я" удалять нельзя

    final List<Person> people = await loadPeople();
    people.removeWhere((p) => p.id == id);

    final String json = jsonEncode(
      people.map((p) => p.toJson()).toList(),
    );
    await _prefs.setString(_key, json);
  }
}
