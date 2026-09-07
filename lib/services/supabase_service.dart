import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';

/// Initialises the Supabase client once at startup.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient? _client;

  static bool get isInitialized => _client != null;

  /// The app-wide Supabase client. Only use after [initialize] succeeded.
  static SupabaseClient get client {
    final c = _client;
    if (c == null) {
      throw StateError('Supabase chưa được khởi tạo (thiếu cấu hình).');
    }
    return c;
  }

  /// Safe initialiser — never crashes the app when offline/not configured.
  static Future<void> initialize() async {
    if (!AppConfig.isConfigured || _client != null) return;
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _tryAnonymousSignIn();
    } catch (_) {
      // First launch without network: repositories fall back to local cache.
    }
  }

  /// Optional: if "Anonymous sign-ins" is enabled in Supabase Auth this
  /// creates a stable anonymous session (helps future RLS setups).
  /// Fails silently when the feature is disabled or offline.
  static void _tryAnonymousSignIn() {
    unawaited(_anonymousSignIn());
  }

  static Future<void> _anonymousSignIn() async {
    try {
      final auth = _client!.auth;
      if (auth.currentSession == null) {
        await auth.signInAnonymously();
      }
    } catch (_) {
      // Feature disabled or offline — anonymous flow is optional.
    }
  }
}
