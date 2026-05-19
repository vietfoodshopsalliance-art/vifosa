// lib/features/home/widgets/radius_selector.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../home_provider.dart';

class RadiusSelector extends ConsumerWidget {
  const RadiusSelector({super.key});

  static const _options = [5, 10, 25];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRadiusProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _options.map((km) {
          final isSelected = selected == km;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('$km km'),
              selected: isSelected,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) {
                ref.read(selectedRadiusProvider.notifier).state = km;
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
