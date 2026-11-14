import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shah_brothers/app.dart';
import 'package:shah_brothers/data/repositories/local_persistence.dart';
import 'package:shah_brothers/data/repositories/local_repository.dart';
import 'package:shah_brothers/providers/providers.dart';

/// Smoke test: login screen shows demo accounts, and each role lands on its
/// own home screen.
void main() {
  final seed = jsonDecode(File('assets/demo/seed.json').readAsStringSync()) as Map<String, dynamic>;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<LocalRepository> makeRepo() async {
    final repo = LocalRepository(persistence: MemoryLocalPersistence(), seedLoader: () async => seed);
    await repo.init();
    return repo;
  }

  Future<void> pumpFor(WidgetTester tester, [int frames = 12]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> boot(WidgetTester tester, LocalRepository repo) async {
    tester.view.physicalSize = const Size(1170, 2532); // phone, 3x
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: const ShahBrothersApp(),
    ));
    await pumpFor(tester);
  }

  Future<void> signInAs(WidgetTester tester, String roleLabel) async {
    await tester.tap(find.text(roleLabel).first);
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await pumpFor(tester, 20);
  }

  testWidgets('login screen lists demo credentials', (tester) async {
    final repo = await tester.runAsync(makeRepo);
    await boot(tester, repo!);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('DEMO ACCOUNTS'), findsOneWidget);
    expect(find.textContaining('owner@shahbrothers.in'), findsOneWidget);
    expect(find.textContaining('manager@shahbrothers.in'), findsOneWidget);
    expect(find.textContaining('priya@shahbrothers.in'), findsOneWidget);
  });

  testWidgets('owner signs in to the analytics dashboard', (tester) async {
    final repo = await tester.runAsync(makeRepo);
    await boot(tester, repo!);
    await signInAs(tester, 'Owner');
    expect(find.textContaining('Rajesh'), findsWidgets);
    expect(find.textContaining('REVENUE'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget); // bottom navigation
  });

  testWidgets('manager signs in to the billing home', (tester) async {
    final repo = await tester.runAsync(makeRepo);
    await boot(tester, repo!);
    await signInAs(tester, 'Manager');
    expect(find.text('New bill'), findsWidgets);
    expect(find.textContaining("Today's counter"), findsOneWidget);
    expect(find.textContaining('REVENUE'), findsNothing); // no business analytics
  });

  testWidgets('salesperson sees only personal performance', (tester) async {
    final repo = await tester.runAsync(makeRepo);
    await boot(tester, repo!);
    await signInAs(tester, 'Salesperson');
    expect(find.textContaining('Priya'), findsWidgets);
    expect(find.text('My Sales'), findsOneWidget);
    expect(find.text('Team'), findsNothing);
    expect(find.text('New bill'), findsNothing);
  });
}
