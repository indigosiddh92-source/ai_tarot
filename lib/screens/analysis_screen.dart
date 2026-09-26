import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/tarot_card.dart';
import '../services/vision_service.dart';
import '../utils/app_exceptions.dart';

/// Экран с анимированной загрузкой во время анализа.
///
/// Этап 4A: реальный вызов Gemini Vision API.
/// Этап 4A.2: «карт не найдено» - это отдельное понятное состояние,
/// а не техническая ошибка. Пользователю предлагается сделать новое фото.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    super.key,
    required this.imageBytes,
    required this.visionService,
    required this.onAnalysisComplete,
    required this.onRetakePhoto,
  });

  /// Bytes подготовленного изображения расклада (готовит ImageService).
  final Uint8List imageBytes;

  /// Vision Service для распознавания карт (Gemini на Этапе 4A).
  final VisionService visionService;

  /// Callback при успешном распознавании.
  final void Function(List<TarotCard> cards) onAnalysisComplete;

  /// Возврат на PhotoScreen для повторной съёмки всего расклада.
  final VoidCallback onRetakePhoto;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

/// Чем закончился анализ.
enum _Outcome { running, noCards, failed }

class _AnalysisScreenState extends State<AnalysisScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  int _stage = 0; // 0: распознавание, 1: определение положений, 2: готово
  _Outcome _outcome = _Outcome.running;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    try {
      // Этап 1: распознавание карт через Gemini Vision API
      setState(() => _stage = 0);

      final List<TarotCard> cards =
          await widget.visionService.recognizeCards(widget.imageBytes);

      if (!mounted) return;

      // Этап 2: определение положений (пришло вместе с ответом Vision API)
      setState(() => _stage = 1);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Этап 3: готово
      setState(() => _stage = 2);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      widget.onAnalysisComplete(cards);
    } on NoCardsFoundException {
      // Не ошибка API: на фото просто нет карт. Диалог не показываем.
      if (!mounted) return;
      setState(() => _outcome = _Outcome.noCards);
    } on AppException catch (e) {
      // Текст AppException уже безопасен и написан для пользователя.
      if (!mounted) return;
      setState(() {
        _outcome = _Outcome.failed;
        _errorMessage = '$e';
      });
      _showErrorDialog('$e');
    } catch (_) {
      // Текст исключения не показываем: он может содержать URL запроса
      // с query-параметром key=. Только безопасное обобщённое сообщение.
      if (!mounted) return;
      const String safeMessage =
          'Не удалось распознать карты.\nПопробуйте ещё раз.';
      setState(() {
        _outcome = _Outcome.failed;
        _errorMessage = safeMessage;
      });
      _showErrorDialog(safeMessage);
    }
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Ошибка'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.onRetakePhoto();
            },
            child: const Text('Сделать новое фото'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (_outcome) {
              _Outcome.running => _buildProgress(theme),
              _Outcome.noCards => _buildMessage(
                  theme,
                  icon: Icons.search_off,
                  title: 'Не удалось найти карты на фотографии.',
                  hint: 'Разложите карты полностью в пределах кадра, '
                      'сфотографируйте расклад сверху при хорошем свете.',
                ),
              _Outcome.failed => _buildMessage(
                  theme,
                  icon: Icons.error_outline,
                  title: _errorMessage ??
                      'Не удалось распознать карты.\nПопробуйте ещё раз.',
                  hint: null,
                ),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(ThemeData theme) {
    final String message = switch (_stage) {
      0 => '🔮 Анализируем ваш расклад...',
      1 => '🃏 Определяем положения карт...',
      _ => '✨ Готово!',
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(_controller),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.gold,
            ),
          ),
        ),
        const SizedBox(height: 32),
        if (_stage < 2)
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.gold.withValues(alpha: 0.7),
              ),
            ),
          )
        else
          const Icon(Icons.check_circle, size: 48, color: AppTheme.gold),
      ],
    );
  }

  Widget _buildMessage(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String? hint,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 48, color: AppTheme.danger),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (hint != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textFaint,
            ),
          ),
        ],
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: widget.onRetakePhoto,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Сделать новое фото'),
        ),
      ],
    );
  }
}
