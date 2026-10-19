// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';
import 'package:frontend/services/mock_api_service.dart';

void main() {
  testWidgets('Login screen renders without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ArtemisApp());

    // Verify that we're on the login screen (after splash).
    await tester.pumpAndSettle();

    // Verify that the title and subtitle are displayed.
    expect(find.text('Acesse sua conta.'), findsOneWidget);
    expect(find.text('proteja quem você ama!'), findsOneWidget);

    // Verify that email and password fields are present.
    expect(find.text('Digite seu usuário'), findsOneWidget);
    expect(find.text('Digite sua senha'), findsOneWidget);

    // Verify that login button and register link are present.
    expect(find.text('ENTRAR'), findsOneWidget);
    expect(find.text('Registrar'), findsOneWidget);
  });
}
