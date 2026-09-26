import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_theme.dart';
import '../models/person.dart';
import '../models/tarot_card.dart';
import '../models/tarot_reading.dart';
import '../services/anymodel_vision_service.dart';
import '../services/storage_service.dart';
import '../services/storage_service_impl.dart';
import '../services/vision_service.dart';
import '../widgets/config_banner.dart';
import 'analysis_screen.dart';
import 'people_screen.dart';
import 'person_selection_screen.dart';
import 'photo_screen.dart';
import 'result_screen.dart';

/// Главный экран: ввод вопроса и навигация на выбор человека.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _questionController = TextEditingController();
  late Future<StorageService> _storageServiceFuture;
  bool _hasQuestion = false;

  @override
  void initState() {
    super.initState();
    _questionController.addListener(_onQuestionChanged);
    _storageServiceFuture = _initializeStorage();
  }

  Future<StorageService> _initializeStorage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return StorageServiceImpl(prefs);
  }

  void _onQuestionChanged() {
    final bool hasText = _questionController.text.trim().isNotEmpty;
    if (hasText != _hasQuestion) {
      setState(() => _hasQuestion = hasText);
    }
  }

  Future<void> _startReading() async {
    final String question = _questionController.text.trim();
    if (question.isEmpty) return;

    final StorageService storageService = await _storageServiceFuture;

    if (!mounted) return;
    _navigateToPersonSelection(question, storageService);
  }

  void _navigateToPersonSelection(
    String question,
    StorageService storageService,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonSelectionScreen(
          question: question,
          storageService: storageService,
          onPersonSelected: (person) {
            _navigateToPhotoScreen(question, person, storageService);
          },
        ),
      ),
    );
  }

  /// PhotoScreen -> AnalysisScreen -> VisionService -> ResultScreen.
  ///
  /// Повторная съёмка расклада использует ровно этот же путь: отдельной
  /// системы повторного анализа нет.
  void _navigateToPhotoScreen(
    String question,
    Person person,
    StorageService storageService,
  ) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PhotoScreen(
          question: question,
          person: person,
          onPhotoSelected: (Uint8List imageBytes, String imagePath) {
            _navigateToAnalysis(question, person, imageBytes, storageService);
          },
        ),
      ),
    );
  }

  void _navigateToAnalysis(
    String question,
    Person person,
    Uint8List imageBytes,
    StorageService storageService,
  ) {
    // Реальный Vision Service (AnyModel, OpenAI-compatible API)
    final VisionService visionService = AnyModelVisionService();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AnalysisScreen(
          imageBytes: imageBytes,
          visionService: visionService,
          onRetakePhoto: () =>
              _navigateToPhotoScreen(question, person, storageService),
          onAnalysisComplete: (List<TarotCard> cards) {
            if (!mounted) return;

            final TarotReading reading = TarotReading(
              question: question,
              person: person,
              cards: cards,
              interpretation:
                  'Интерпретация расклада будет доступна на Этапе 4B.',
              createdAt: DateTime.now(),
            );

            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => ResultScreen(
                  reading: reading,
                  // Переснять весь расклад: тот же вопрос, тот же человек,
                  // новое фото, обычный поток анализа.
                  onRetakePhoto: () =>
                      _navigateToPhotoScreen(question, person, storageService),
                  onNewReading: () {
                    _questionController.clear();
                    Navigator.of(context)
                        .popUntil((Route<dynamic> route) => route.isFirst);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _navigateToPeople() async {
    final StorageService storageService = await _storageServiceFuture;
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PeopleScreen(
          storageService: storageService,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _questionController
      ..removeListener(_onQuestionChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 32),
              const Icon(Icons.auto_awesome, size: 48, color: AppTheme.gold),
              const SizedBox(height: 20),
              Text(
                'AI Tarot',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Задайте вопрос. Покажите расклад. Получите интерпретацию.',
                textAlign: TextAlign.center,
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSoft),
              ),
              const SizedBox(height: 40),
              Text('Ваш вопрос', style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              TextField(
                controller: _questionController,
                minLines: 4,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Например: Стоит ли мне принимать '
                      'предложение о новой работе?',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _hasQuestion ? _startReading : null,
                child: const Text('Начать расклад'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _navigateToPeople,
                child: const Text('Мои люди'),
              ),
              const SizedBox(height: 32),
              const ConfigBanner(),
              const SizedBox(height: 16),
              Text(
                'Инструмент символической интерпретации и саморефлексии, '
                'а не предсказание будущего.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.textFaint),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
