/// Человек, на которого делается расклад. Хранится только локально.
class Person {
  const Person({
    required this.id,
    required this.alias,
    this.description = '',
    this.isSelf = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Идентификатор профиля «Я» - он существует по умолчанию.
  static const String selfId = 'self';

  final String id;
  final String alias;
  final String description;

  /// true только у профиля «Я»: его можно редактировать, но не удалять.
  final bool isSelf;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Person.self() => Person(
        id: selfId,
        alias: 'Я',
        isSelf: true,
        createdAt: DateTime.now(),
      );

  Person copyWith({
    String? alias,
    String? description,
    DateTime? updatedAt,
  }) {
    return Person(
      id: id,
      alias: alias ?? this.alias,
      description: description ?? this.description,
      isSelf: isSelf,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'alias': alias,
        'description': description,
        'isSelf': isSelf,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        id: json['id'] as String,
        alias: json['alias'] as String? ?? 'Без имени',
        description: json['description'] as String? ?? '',
        isSelf: json['isSelf'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      );
}
