import 'dart:convert';
import 'dart:ui' show Offset, Rect;

import 'package:http/http.dart' as http;

// Where the HerdGuard backend runs.
// Web / desktop      -> http://localhost:8000
// Android emulator   -> http://10.0.2.2:8000
// Real phone, Wi-Fi  -> http://YOUR-PC-IP:8000
const String baseUrl = 'http://localhost:8000';

class Animal {
  final String id, tag, name, status;
  final double x, y, temp, activity, battery, speed;
  final bool alarm;
  final List<Offset> trail;

  Animal({
    required this.id,
    required this.tag,
    required this.name,
    required this.status,
    required this.x,
    required this.y,
    required this.temp,
    required this.activity,
    required this.battery,
    required this.speed,
    required this.alarm,
    required this.trail,
  });

  Offset get pos => Offset(x, y);

  factory Animal.fromJson(Map<String, dynamic> j) => Animal(
        id: j['id'] as String,
        tag: j['tag'] as String,
        name: j['name'] as String,
        status: j['status'] as String,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        temp: (j['temp'] as num).toDouble(),
        activity: (j['activity'] as num).toDouble(),
        battery: (j['battery'] as num).toDouble(),
        speed: (j['speed'] as num).toDouble(),
        alarm: j['alarm'] as bool,
        trail: (j['trail'] as List)
            .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList(),
      );
}

class AlertItem {
  final String id, animalId, kind, severity, message;
  final DateTime time;
  final bool acknowledged, active;

  AlertItem({
    required this.id,
    required this.animalId,
    required this.kind,
    required this.severity,
    required this.message,
    required this.time,
    required this.acknowledged,
    required this.active,
  });

  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
        id: j['id'] as String,
        animalId: j['animal_id'] as String,
        kind: j['kind'] as String,
        severity: j['severity'] as String,
        message: j['message'] as String,
        time: DateTime.fromMillisecondsSinceEpoch(
            ((j['ts'] as num) * 1000).round()),
        acknowledged: j['acknowledged'] as bool,
        active: j['active'] as bool,
      );
}

class Farm {
  final List<Offset> fence;
  final Rect bounds;
  final List<Animal> animals;
  final List<AlertItem> alerts;

  Farm(this.fence, this.bounds, this.animals, this.alerts);

  factory Farm.fromJson(Map<String, dynamic> j) {
    final b = (j['bounds'] as List).map((e) => (e as num).toDouble()).toList();
    return Farm(
      (j['fence'] as List)
          .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList(),
      Rect.fromLTRB(b[0], b[1], b[2], b[3]),
      (j['animals'] as List)
          .map((e) => Animal.fromJson(e as Map<String, dynamic>))
          .toList(),
      (j['alerts'] as List)
          .map((e) => AlertItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Animal? animal(String? id) {
    for (final a in animals) {
      if (a.id == id) return a;
    }
    return null;
  }

  int get openAlerts => alerts.where((a) => a.active && !a.acknowledged).length;
  int get healthy => animals.where((a) => a.status == 'ok').length;
}

class Api {
  static Future<Farm> fetchFarm() async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/state'))
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) throw Exception('Server error');
    return Farm.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> post(String path) async {
    final res = await http
        .post(Uri.parse('$baseUrl$path'))
        .timeout(const Duration(seconds: 6));
    if (res.statusCode >= 400) throw Exception('Request failed');
  }
}

String ago(DateTime t) {
  final s = DateTime.now().difference(t).inSeconds;
  if (s < 5) return 'just now';
  if (s < 60) return '${s}s ago';
  if (s < 3600) return '${s ~/ 60}m ago';
  return '${s ~/ 3600}h ago';
}
