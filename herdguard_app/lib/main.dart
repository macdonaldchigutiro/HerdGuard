import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'alerts_screen.dart';
import 'animal_panel.dart';
import 'api.dart';
import 'herd_screen.dart';
import 'radar_view.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Palette.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const HerdGuardApp());
}

class HerdGuardApp extends StatelessWidget {
  const HerdGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HerdGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.bg,
        colorScheme: const ColorScheme.dark(
          primary: Palette.green,
          secondary: Palette.cyan,
        ),
        useMaterial3: true,
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Farm? _farm;
  bool _offline = false;
  Timer? _timer;
  int _tab = 0;
  String? _selectedId;
  String? _locateId;
  final Set<String> _seen = {};
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final f = await Api.fetchFarm();
      if (!mounted) return;
      _checkNewAlerts(f);
      setState(() {
        _farm = f;
        _offline = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _offline = true);
    }
  }

  void _checkNewAlerts(Farm f) {
    for (final a in f.alerts) {
      if (_seen.add(a.id) &&
          !_firstLoad &&
          a.severity == 'critical' &&
          a.active) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF7A1226),
          content: Text(a.message),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () => _focus(a.animalId),
          ),
        ));
      }
    }
    _firstLoad = false;
  }

  void _focus(String id) {
    setState(() {
      _selectedId = id;
      _tab = 0;
    });
  }

  Future<void> _call(String path, {String? message}) async {
    try {
      await Api.post(path);
      if (message != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ));
      }
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text("Couldn't reach the server."),
      ));
    }
  }

  void _locate(String id) {
    HapticFeedback.mediumImpact();
    setState(() => _locateId = id);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _locateId == id) setState(() => _locateId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final farm = _farm;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              if (_offline)
                Container(
                  width: double.infinity,
                  color: const Color(0x33FF4D6D),
                  padding: const EdgeInsets.all(6),
                  child: const Text(
                    'Offline: trying to reconnect…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Palette.red, fontSize: 12),
                  ),
                ),
              Expanded(
                child: farm == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Palette.green),
                            SizedBox(height: 14),
                            Text('Connecting to herd network…',
                                style: TextStyle(color: Palette.textDim)),
                          ],
                        ),
                      )
                    : IndexedStack(
                        index: _tab,
                        children: [
                          _radarPage(farm),
                          AlertsScreen(
                            farm: farm,
                            onFocus: _focus,
                            onAck: (id) => _call('/api/alerts/$id/ack'),
                          ),
                          HerdScreen(farm: farm, onFocus: _focus),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF08131F),
        indicatorColor: Palette.cyan.withOpacity(0.18),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.radar), label: 'Radar'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: (farm?.openAlerts ?? 0) > 0,
              label: Text('${farm?.openAlerts ?? 0}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
              icon: Icon(Icons.pets), label: 'Herd'),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (r) => neonGradient.createShader(r),
                  child: const Text(
                    'HERDGUARD',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Text('LIVE LIVESTOCK MONITORING',
                    style: TextStyle(
                        color: Palette.textDim, fontSize: 10, letterSpacing: 3)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.science_outlined, color: Palette.cyan),
            tooltip: 'Demo controls',
            color: const Color(0xFF0E2236),
            onSelected: (v) {
              switch (v) {
                case 'theft':
                  _call('/api/demo/theft', message: 'Theft simulation started');
                  break;
                case 'fever':
                  _call('/api/demo/fever', message: 'Fever simulation started');
                  break;
                default:
                  _selectedId = null;
                  _seen.clear();
                  _firstLoad = true;
                  _call('/api/demo/reset', message: 'Demo reset');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'theft', child: Text('Simulate theft')),
              PopupMenuItem(value: 'fever', child: Text('Simulate fever')),
              PopupMenuItem(value: 'reset', child: Text('Reset demo')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _radarPage(Farm farm) {
    final selected = farm.animal(_selectedId);
    final hasOpen = selected != null &&
        farm.alerts.any((a) =>
            a.animalId == selected.id && a.active && !a.acknowledged);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              _chip('${farm.animals.length} animals', Palette.text),
              const SizedBox(width: 8),
              _chip('${farm.healthy} healthy', Palette.green),
              const SizedBox(width: 8),
              _chip('${farm.openAlerts} alerts',
                  farm.openAlerts > 0 ? Palette.red : Palette.textDim),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RadarView(
              farm: farm,
              selectedId: _selectedId,
              locateId: _locateId,
              onSelect: (id) => setState(() => _selectedId = id),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: selected == null
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Tap an animal on the radar. Pinch to zoom.',
                      style: TextStyle(color: Palette.textDim, fontSize: 13),
                    ),
                  )
                : AnimalPanel(
                    animal: selected,
                    hasOpenAlert: hasOpen,
                    onLocate: () => _locate(selected.id),
                    onSafe: () => _call('/api/animals/${selected.id}/safe'),
                    onClose: () => setState(() => _selectedId = null),
                  ),
          ),
        ],
      ),
    );
  }
}
