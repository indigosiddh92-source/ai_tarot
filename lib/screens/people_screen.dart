import 'package:flutter/material.dart';

import '../models/person.dart';
import '../services/storage_service.dart';
import '../widgets/person_card.dart';
import 'person_edit_screen.dart';

/// Экран управления сохранёнными людьми.
/// Возможность редактировать, добавлять и удалять профили.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({
    super.key,
    required this.storageService,
  });

  final StorageService storageService;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  late Future<List<Person>> _peopleFuture;

  @override
  void initState() {
    super.initState();
    _refreshPeople();
  }

  void _refreshPeople() {
    _peopleFuture = widget.storageService.loadPeople();
  }

  Future<void> _navigateToEditPerson(Person person) async {
    final Person? result = await Navigator.of(context).push<Person>(
      MaterialPageRoute(
        builder: (_) => PersonEditScreen(
          storageService: widget.storageService,
          person: person,
        ),
      ),
    );

    if (result != null) {
      setState(() => _refreshPeople());
    }
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
        title: const Text('Мои люди'),
      ),
      body: FutureBuilder<List<Person>>(
        future: _peopleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Ошибка: ${snapshot.error}'),
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
                onTap: () => _navigateToEditPerson(person),
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
