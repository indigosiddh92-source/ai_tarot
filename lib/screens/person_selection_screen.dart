import 'package:flutter/material.dart';

import '../models/person.dart';
import '../services/storage_service.dart';
import '../widgets/person_card.dart';
import 'person_edit_screen.dart';

/// Выбор человека для расклада.
/// Показывает список сохранённых людей и кнопку добавления нового.
class PersonSelectionScreen extends StatefulWidget {
  const PersonSelectionScreen({
    super.key,
    required this.question,
    required this.storageService,
    required this.onPersonSelected,
  });

  final String question;
  final StorageService storageService;
  final void Function(Person) onPersonSelected;

  @override
  State<PersonSelectionScreen> createState() => _PersonSelectionScreenState();
}

class _PersonSelectionScreenState extends State<PersonSelectionScreen> {
  late Future<List<Person>> _peopleFuture;

  @override
  void initState() {
    super.initState();
    _refreshPeople();
  }

  void _refreshPeople() {
    _peopleFuture = widget.storageService.loadPeople();
  }

  Future<void> _navigateToAddPerson() async {
    final Person? result = await Navigator.of(context).push<Person>(
      MaterialPageRoute(
        builder: (_) => PersonEditScreen(
          storageService: widget.storageService,
        ),
      ),
    );

    if (result != null) {
      setState(() => _refreshPeople());
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('На кого делается расклад?'),
      ),
      body: FutureBuilder<List<Person>>(
        future: _peopleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Ошибка загрузки: ${snapshot.error}'),
            );
          }

          final List<Person> people = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: people.length + 1,
            itemBuilder: (context, index) {
              if (index == people.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.icon(
                    onPressed: _navigateToAddPerson,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить человека'),
                  ),
                );
              }

              final Person person = people[index];
              return PersonCard(
                person: person,
                onTap: () => widget.onPersonSelected(person),
                storageService: widget.storageService,
                onChanged: () => setState(() => _refreshPeople()),
              );
            },
          );
        },
      ),
    );
  }
}
