import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/person.dart';
import '../services/storage_service.dart';

/// Карточка профиля человека в списке.
/// Нажатие: выбор/редактирование. Свайп: удаление (если не "Я").
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.person,
    required this.onTap,
    required this.storageService,
    required this.onChanged,
  });

  final Person person;
  final VoidCallback onTap;
  final StorageService storageService;
  final VoidCallback onChanged;

  Future<void> _deletePerson(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить профиль "${person.alias}"?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await storageService.deletePerson(person.id);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        onLongPress: !person.isSelf ? () => _deletePerson(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    person.alias,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (person.isSelf)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '✨',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              if (person.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  person.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
