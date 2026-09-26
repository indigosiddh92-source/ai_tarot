import 'package:ai_tarot/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'главный экран показывает название, вопрос и кнопки навигации',
    (WidgetTester tester) async {
      await tester.pumpWidget(const AiTarotApp());

      expect(find.text('AI Tarot'), findsOneWidget);
      expect(find.text('Ваш вопрос'), findsOneWidget);
      expect(find.text('Начать расклад'), findsOneWidget);
      expect(find.text('Мои люди'), findsOneWidget);
    },
  );
}
