import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/recognition_summary.dart';

/// Карточка распознанной карты Таро в результате.
///
/// Техническое значение `unknown` пользователю не показывается:
/// вместо него выводится понятный русский текст.
class TarotCardResult extends StatelessWidget {
  const TarotCardResult({
    super.key,
    required this.positionedCard,
  });

  final PositionedCard positionedCard;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool recognized = positionedCard.card.isRecognized;
    final Color accent = recognized ? AppTheme.purple : AppTheme.textFaint;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              '${positionedCard.position}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  positionedCard.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: recognized ? AppTheme.gold : AppTheme.textSoft,
                  ),
                ),
                const SizedBox(height: 4),
                // Для unknown показываем честный текст, а не догадку.
                Text(
                  positionedCard.card.orientation.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textFaint,
                    fontStyle: positionedCard.card.orientation.isKnown
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
