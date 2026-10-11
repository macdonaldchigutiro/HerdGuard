import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';

class AnimalPanel extends StatelessWidget {
  final Animal animal;
  final bool hasOpenAlert;
  final VoidCallback onLocate;
  final VoidCallback onSafe;
  final VoidCallback onClose;

  const AnimalPanel({
    super.key,
    required this.animal,
    required this.hasOpenAlert,
    required this.onLocate,
    required this.onSafe,
    required this.onClose,
  });

  String get _label {
    switch (animal.status) {
      case 'critical':
        return 'ALERT';
      case 'warning':
        return 'WATCH';
      default:
        return 'HEALTHY';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Palette.forStatus(animal.status);
    final feverish = animal.temp >= 39.6;
    final double tempProgress =
        ((animal.temp - 36) / 6).clamp(0.0, 1.0).toDouble();

    return GlassCard(
      borderColor: color.withOpacity(0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(animal.name,
                        style: const TextStyle(
                            color: Palette.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    Text('Tag ${animal.tag}',
                        style: const TextStyle(
                            color: Palette.textDim, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color),
                ),
                child: Text(_label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Palette.textDim, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _gauge('TEMP', '${animal.temp.toStringAsFixed(1)} °C', tempProgress,
              feverish ? Palette.amber : Palette.green),
          _gauge('ACTIVITY', '${animal.activity.round()}%',
              animal.activity / 100, Palette.cyan),
          _gauge('BATTERY', '${animal.battery.round()}%',
              animal.battery / 100,
              animal.battery < 15 ? Palette.red : Palette.green),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onLocate,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('LOCATE'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.cyan,
                    side: const BorderSide(color: Palette.cyan),
                  ),
                ),
              ),
              if (hasOpenAlert) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSafe,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('MARK SAFE'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.green,
                      foregroundColor: Palette.bg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _gauge(String label, String value, double progress, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(label,
                style: const TextStyle(
                    color: Palette.textDim, fontSize: 11, letterSpacing: 2)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
                color: color,
                backgroundColor: Palette.glassBorder,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
