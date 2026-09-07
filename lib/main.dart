import 'package:flutter/material.dart';

import 'app.dart';
import 'data/local_store.dart';
import 'services/app_services.dart';
import 'services/connectivity_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Try to connect to Supabase (never blocks/crashes when offline).
  await SupabaseService.initialize();

  // 2. Watch network state (offline banner).
  await ConnectivityService.instance.start();

  // 3. Wire up repositories/services (single composition root).
  final services = AppServices(store: LocalStore.instance);

  runApp(QuanLyRauApp(services: services));
}
