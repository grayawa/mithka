//
//  main.dart
//
//  MithkalApp entry point. Wires the controllers (AuthManager, ThemeController,
//  AccountStore, DrawerController) as providers, applies the adaptive theme +
//  themeMode, and keys the content on the active account so the whole tree
//  rebuilds for the newly active account. Port of the Swift `MithkalApp`.
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/content_view.dart';
import 'auth/account_store.dart';
import 'auth/auth_manager.dart';
import 'components/drawer_controller.dart' as dc;
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only — no landscape.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final prefs = await SharedPreferences.getInstance();
  runApp(MithkalApp(prefs: prefs));
}

class MithkalApp extends StatefulWidget {
  const MithkalApp({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  State<MithkalApp> createState() => _MithkalAppState();
}

class _MithkalAppState extends State<MithkalApp> {
  late final AuthManager _auth = AuthManager();
  late final ThemeController _theme = ThemeController(widget.prefs);
  late final AccountStore _accounts = AccountStore(widget.prefs);
  late final dc.DrawerController _drawer = dc.DrawerController();

  @override
  void initState() {
    super.initState();
    _auth.start();
  }

  ThemeData _themeData(Brightness brightness) {
    final colors = brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTheme.brand,
        brightness: brightness,
      ),
      extensions: [colors],
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _theme),
        ChangeNotifierProvider.value(value: _accounts),
        ChangeNotifierProvider<dc.DrawerController>.value(value: _drawer),
      ],
      child: Consumer2<ThemeController, AccountStore>(
        builder: (context, theme, accounts, _) {
          return MaterialApp(
            title: 'Mithkal',
            debugShowCheckedModeBanner: false,
            theme: _themeData(Brightness.light),
            darkTheme: _themeData(Brightness.dark),
            themeMode: theme.themeMode,
            // Rebuild the whole tree when the active account changes.
            home: KeyedSubtree(
              key: ValueKey(accounts.activeSlot),
              child: const ContentView(),
            ),
          );
        },
      ),
    );
  }
}
