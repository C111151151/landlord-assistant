import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:landlord_assistant/main.dart';

void main() {
  testWidgets('MetricCard displays its content', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MetricCard(
            title: '本月租金',
            value: 'NT\$ 25,000',
            note: '已收款',
            icon: Icons.payments_rounded,
            color: Colors.green,
          ),
        ),
      ),
    );

    expect(find.text('本月租金'), findsOneWidget);
    expect(find.text('NT\$ 25,000'), findsOneWidget);
    expect(find.text('已收款'), findsOneWidget);
    expect(find.byIcon(Icons.payments_rounded), findsOneWidget);
  });
}
