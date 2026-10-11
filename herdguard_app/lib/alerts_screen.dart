import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';

class AlertsScreen extends StatelessWidget {
  final Farm farm;
  final ValueChanged<String> onFocus;
  final ValueChanged<String> onAck;

  const AlertsScreen({
    super.key,
    required this.farm,
    required this.onFocus,
    required this.onAck,
  });

  IconData _icon(String kind) {
    switch (kind) {
      case 'fence':
        return Icons.fence;
      case 'fever':
        return Icons.thermostat;
      case 'inactive':
        return Icons.hotel;
      default:
        return Icons.battery_alert;
    }
  }

  Color _color(String severity) {
    switch (severity) {
      case 'critical':
        return Palette.red;
      case 'warning':
        return Palette.amber;
      default:
        return Palette.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (farm.alerts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user, size: 56, color: Palette.green),
            SizedBox(height: 12),
            Text('All clear', style: TextStyle(color: Palette.text, fontSize: 18)),
            Text('No alerts right now',
                style: TextStyle(color: Palette.textDim)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: farm.alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final a = farm.alerts[i];
        final color = _color(a.severity);
        final open = a.active && !a.acknowledged;
        return Opacity(
          opacity: a.active ? 1 : 0.5,
          child: GestureDetector(
            onTap: () => onFocus(a.animalId),
            child: GlassCard(
              borderColor: open ? color.withOpacity(0.6) : null,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.15),
                    ),
                    child: Icon(_icon(a.kind), color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.message,
                            style: const TextStyle(
                                color: Palette.text, height: 1.3)),
                        const SizedBox(height: 4),
                        Text(
                          '${ago(a.time)}  •  ${a.active ? (a.acknowledged ? "ACKNOWLEDGED" : "ACTIVE") : "RESOLVED"}',
                          style: const TextStyle(
                              color: Palette.textDim,
                              fontSize: 11,
                              letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                  if (open)
                    TextButton(
                      onPressed: () => onAck(a.id),
                      child: const Text('ACK',
                          style: TextStyle(color: Palette.cyan)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
