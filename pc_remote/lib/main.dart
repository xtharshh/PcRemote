import 'package:flutter/material.dart';
import 'api.dart';
import 'links.dart';
import 'theme.dart';
import 'screens/gate.dart';
import 'screens/home.dart';
import 'screens/brightness.dart';
import 'screens/profiles.dart';
import 'screens/folders.dart';
import 'screens/power.dart';
import 'widgets/ui.dart';

void main() => runApp(const LumenDeskApp());

/// Lumen Desk — one name + one mark on Windows and Android:
/// brightness, profiles & lock, from your phone.
class LumenDeskApp extends StatefulWidget {
  const LumenDeskApp({super.key});

  @override
  State<LumenDeskApp> createState() => _LumenDeskAppState();
}

// Keep the old names working for existing tests / imports.
typedef LumiLinkApp = LumenDeskApp;
typedef PcRemoteApp = LumenDeskApp;

class _LumenDeskAppState extends State<LumenDeskApp> {
  PcApi? _api;
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumen Desk',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: _api == null
          ? GateScreen(onUnlock: (api) => setState(() => _api = api))
          : Scaffold(
              appBar: AppBar(
                leading: const Padding(
                  padding: EdgeInsets.all(8),
                  child: AppLogo(size: 32),
                ),
                title: Text(_api!.displayName.isEmpty
                    ? 'Lumen Desk'
                    : 'Lumen Desk · ${_api!.displayName}'),
                actions: [
                  IconButton(
                    tooltip: 'Download Windows module (GitHub)',
                    icon: const Icon(Icons.download_for_offline_outlined),
                    onPressed: () => AppLinks.openWindowsDownload(context),
                  ),
                  IconButton(
                    tooltip: 'Change PC',
                    icon: const Icon(Icons.wifi_find),
                    onPressed: () => setState(() {
                      _api = null;
                      _tab = 0;
                    }),
                  ),
                ],
              ),
              body: IndexedStack(
                index: _tab,
                children: [
                  HomeScreen(
                      api: _api!,
                      onChangePc: () => setState(() {
                            _api = null;
                            _tab = 0;
                          })),
                  BrightnessScreen(api: _api!),
                  ProfilesScreen(api: _api!),
                  FoldersScreen(api: _api!),
                  PowerScreen(api: _api!),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.home), label: 'Home'),
                  NavigationDestination(
                      icon: Icon(Icons.brightness_6), label: 'Bright'),
                  NavigationDestination(
                      icon: Icon(Icons.people), label: 'Profiles'),
                  NavigationDestination(
                      icon: Icon(Icons.folder), label: 'Folders'),
                  NavigationDestination(
                      icon: Icon(Icons.power_settings_new),
                      label: 'Power'),
                ],
              ),
            ),
    );
  }
}
