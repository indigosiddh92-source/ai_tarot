import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/person.dart';
import '../services/storage_service.dart';

/// Экран добавления или редактирования человека.
class PersonEditScreen extends StatefulWidget {
  const PersonEditScreen({
    super.key,
    required this.storageService,
    this.person,
  });

  final StorageService storageService;
  final Person? person;

  @override
  State<PersonEditScreen> createState() => _PersonEditScreenState();
}

class _PersonEditScreenState extends State<PersonEditScreen> {
  late TextEditingController _aliasController;
  late TextEditingController _descriptionController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final Person? person = widget.person;
    _aliasController = TextEditingController(text: person?.alias ?? '');
    _descriptionController = TextEditingController(
      text: person?.description ?? '',
    );
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _savePerson() async {
    final String alias = _aliasController.text.trim();
    if (alias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите псевдоним')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final Person person = Person(
        id: widget.person?.id ?? const Uuid().v4(),
        alias: alias,
        description: _descriptionController.text.trim(),
        isSelf: widget.person?.isSelf ?? false,
        createdAt: widget.person?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await widget.storageService.savePerson(person);

      if (!mounted) return;
      Navigator.of(context).pop(person);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isEditing = widget.person != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Редактировать профиль' : 'Новый профиль'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Псевдоним', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _aliasController,
              enabled: !_isSaving && !widget.person!.isSelf,
              decoration: const InputDecoration(
                hintText: 'Например: Марина',
              ),
            ),
            const SizedBox(height: 28),
            Text('Описание человека', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              enabled: !_isSaving,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Опционально. Например: Женщина, 32 года. '
                    'Переживает сложный период в отношениях.',
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isSaving ? null : _savePerson,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Сохранить'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
          ],
        ),
      ),
    );
  }
}
