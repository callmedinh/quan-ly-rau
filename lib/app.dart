import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/setup/setup_screen.dart';
import 'services/app_services.dart';
import 'services/connectivity_service.dart';

/// Top-level widget tree:
///   Provider<AppServices>            → repositories & services
///   ChangeNotifierProvider<ValueNotifier<bool>> → online status
class QuanLyRauApp extends StatelessWidget {
  const QuanLyRauApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<ValueNotifier<bool>>.value(
          value: ConnectivityService.instance.isOnline,
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: AppConfig.isConfigured ? const HomeShell() : const SetupScreen(),
      ),
    );
  }
}
