import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    expect(find.byType(MaterialApp), findsOneWidget);

    // Unmount before the splash screen's auto-navigation timer fires, so its
    // dispose() cancels it cleanly instead of leaving it pending (and instead
    // of navigating into the landing page's live network calls/timers).
    await tester.pumpWidget(const SizedBox.shrink());
  });
}