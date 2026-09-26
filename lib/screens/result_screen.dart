import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/recognition_summary.dart';
import '../models/tarot_reading.dart';
import '../widgets/tarot_card_result.dart';

/// Экран с результатом расклада: список распознанных карт.
///
/// Этап 4A.2: если часть карт не распознана, это НЕ ошибка. Экран честно
/// говорит, сколько карт не удалось определить, и даёт выбор:
/// переснять весь расклад или продолжить с тем, что есть.
/// Интерпретация появится на Этапе 4B.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.reading,
    required this.onNewReading,
    required this.onRetakePhoto,
  });

  final TarotReading reading;

  /// Полностью новый расклад (с главного экрана).
  final VoidCallback onNewReading;

  /// Переснять весь расклад: возврат на PhotoScreen, дальше обычный поток
  /// PhotoScreen -> AnalysisScreen -> Gemini -> ResultScreen.
  final VoidCallback onRetakePhoto;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  /// Пользователь нажал «Продолжить без этих карт»: предупреждение убрано,
  /// распознанные карты остались на месте.
  bool _acceptedMissingCards = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RecognitionSummary summary =
        RecognitionSummary.fromCards(widget.reading.cards);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Результат расклада'),
        leading: null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildReadingInfo(theme),
            const SizedBox(height: 32),
            if (summary.state == RecognitionState.empty)
              _buildNoCardsBlock(theme)
            else ...<Widget>[
              if (summary.hasUnrecognized && !_acceptedMissingCards) ...<Widget>[
                _buildUnrecognizedBlock(theme, summary),
                const SizedBox(height: 24),
              ],
              _buildCardsList(theme, summary),
              const SizedBox(height: 32),
              _buildInterpretationNote(theme),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: widget.onNewReading,
                child: const Text('Новый расклад'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReadingInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Вопрос',
            style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.gold),
          ),
          const SizedBox(height: 8),
          Text(widget.reading.question, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(
            'Для: ${widget.reading.person.alias}',
            style:
                theme.textTheme.bodySmall?.copyWith(color: AppTheme.textFaint),
          ),
        ],
      ),
    );
  }

  /// Предупреждение о нераспознанных картах + два действия.
  Widget _buildUnrecognizedBlock(ThemeData theme, RecognitionSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dangerTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dangerEdge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.help_outline, color: AppTheme.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary.unrecognizedMessage,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final String label in summary.unrecognizedLabels)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.textSoft),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Попробуйте сфотографировать весь расклад заново: '
            'сверху, при хорошем свете, чтобы карты не перекрывали друг друга.',
            style:
                theme.textTheme.bodySmall?.copyWith(color: AppTheme.textFaint),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: widget.onRetakePhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Переснять расклад'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: summary.hasRecognized
                ? () => setState(() => _acceptedMissingCards = true)
                : null,
            child: const Text('Продолжить без этих карт'),
          ),
        ],
      ),
    );
  }

  /// Gemini не нашёл карт вообще: отдельное состояние.
  Widget _buildNoCardsBlock(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.dangerTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dangerEdge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Не удалось найти карты на фотографии.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.danger),
          ),
          const SizedBox(height: 12),
          Text(
            'Разложите карты полностью в пределах кадра и сфотографируйте '
            'расклад сверху.',
            textAlign: TextAlign.center,
            style:
                theme.textTheme.bodySmall?.copyWith(color: AppTheme.textFaint),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: widget.onRetakePhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Сделать новое фото'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: widget.onNewReading,
            child: const Text('Новый расклад'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsList(ThemeData theme, RecognitionSummary summary) {
    // После «Продолжить без этих карт» показываем только распознанные.
    final List<PositionedCard> visible =
        _acceptedMissingCards ? summary.recognized : summary.cards;

    final String title = summary.hasUnrecognized && !_acceptedMissingCards
        ? 'Карты на фотографии '
            '(${summary.recognizedCount} из ${summary.totalCount} распознано)'
        : 'Распознанные карты (${visible.length})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.gold),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Ни одну карту определить не удалось.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.textFaint),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) =>
                TarotCardResult(positionedCard: visible[index]),
          ),
      ],
    );
  }

  Widget _buildInterpretationNote(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.goldTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldEdge),
      ),
      child: Text(
        widget.reading.interpretation,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.gold),
      ),
    );
  }
}
