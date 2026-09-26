import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';

/// Честно предупреждает, что AI не настроен. Никаких фиктивных ответов.
class ConfigBanner extends StatelessWidget {
  const ConfigBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final bool configured = AppConfig.isAiConfigured;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: configured ? AppTheme.goldTint : AppTheme.dangerTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: configured ? AppTheme.goldEdge : AppTheme.dangerEdge,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            configured ? Icons.check_circle_outline : Icons.key_off_outlined,
            color: configured ? AppTheme.gold : AppTheme.danger,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              configured
                  ? 'AI API настроен. Модель: ${AppConfig.visionModel}'
                  : 'AI API не настроен. Ключ передаётся через AI_API_KEY.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
