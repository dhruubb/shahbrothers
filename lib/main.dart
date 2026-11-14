import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'data/repositories/data_repository.dart';
import 'data/repositories/local_persistence.dart';
import 'data/repositories/local_repository.dart';
import 'data/repositories/supabase_repository.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final repository = await createRepository();

  runApp(ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(repository)],
    child: const ShahBrothersApp(),
  ));
}

/// Supabase when credentials are supplied via --dart-define, otherwise the
/// persistent local demo database.
Future<DataRepository> createRepository() async {
  if (Env.hasSupabase) {
    try {
      await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
      return SupabaseRepository(Supabase.instance.client);
    } catch (e) {
      debugPrint('Supabase init failed, using local demo mode: $e');
    }
  }
  final local = LocalRepository(persistence: FileLocalPersistence());
  await local.init();
  return local;
}
