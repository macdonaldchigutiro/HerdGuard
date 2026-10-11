import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';

class HerdScreen extends StatelessWidget {
  final Farm farm;
  final ValueChanged<String> onFocus;

  const HerdScreen({super.key, required this.farm, required this.onFocus});

  @override
  Widget build(BuildContext context) {
    final animals = [...farm.animals]
      ..sort((a, b) => _rank(b.status).compareTo(_rank(a.status)));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: animals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = animals[i];
        final color = Palette.forStatus(a.status);
        return GestureDetector(
          onTap: () => onFocus(a.id),
          child: GlassCard(
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name,
                          style: const TextStyle(
                              color: Palette.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      Text('Tag ${a.tag}',
                          style: const TextStyle(
                              color: Palette.textDim, fontSize: 12)),
                    ],
                  ),
                ),
                Text('${a.temp.toStringAsFixed(1)}°C',
                    style: TextStyle(
                        color: a.temp >= 39.6 ? Palette.amber : Palette.text,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 14),
                Icon(
                  a.battery < 15 ? Icons.battery_alert : Icons.battery_full,
                  size: 18,
                  color: a.battery < 15 ? Palette.red : Palette.textDim,
                ),
                Text(' ${a.battery.round()}%',
                    style: const TextStyle(color: Palette.textDim, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  int _rank(String s) => s == 'critical' ? 2 : (s == 'warning' ? 1 : 0);
}
