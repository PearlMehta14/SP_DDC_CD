import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ddc_diamonds/main.dart';
import 'package:ddc_diamonds/services/api_service.dart';

void main() {
  setUpAll(() {
    apiService.baseUrl = 'http://127.0.0.1:8000';
  });

  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(MaterialApp), findsWidgets);
  });
}
