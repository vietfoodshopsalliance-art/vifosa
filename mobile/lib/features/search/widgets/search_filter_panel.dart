// lib/features/search/widgets/search_filter_panel.dart
// Panel filter: sort, period, radius — hiện khi bấm nút filter

import 'package:flutter/material.dart';
import '../providers/search_provider.dart' show SearchSort, SearchPeriod;

class SearchFilterPanel extends StatelessWidget {
  final SearchSort currentSort;
  final SearchPeriod currentPeriod;
  final double? currentRadius;
  final ValueChanged<SearchSort> onSortChanged;
  final ValueChanged<SearchPeriod> onPeriodChanged;
  final ValueChanged<double?> onRadiusChanged;

  const SearchFilterPanel({
    super.key,
    required this.currentSort,
    required this.currentPeriod,
    required this.currentRadius,
    required this.onSortChanged,
    required this.onPeriodChanged,
    required this.onRadiusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),

          // ── Sắp xếp ──────────────────────────────────────────
          const _FilterLabel(label: 'Sắp xếp theo'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SortChip(
                  label: 'Đánh giá',
                  selected: currentSort == SearchSort.rating,
                  onTap: () => onSortChanged(SearchSort.rating),
                ),
                _SortChip(
                  label: 'Khoảng cách',
                  selected: currentSort == SearchSort.distance,
                  onTap: () => onSortChanged(SearchSort.distance),
                ),
                _SortChip(
                  label: 'Tên',
                  selected: currentSort == SearchSort.name,
                  onTap: () => onSortChanged(SearchSort.name),
                ),
                _SortChip(
                  label: 'Phổ biến',
                  selected: currentSort == SearchSort.popular,
                  onTap: () => onSortChanged(SearchSort.popular),
                ),
              ],
            ),
          ),

          // ── Khoảng thời gian (chỉ hiện khi sort=popular) ─────
          if (currentSort == SearchSort.popular) ...[
            const SizedBox(height: 12),
            const _FilterLabel(label: 'Khoảng thời gian'),
            const SizedBox(height: 8),
            Row(
              children: [
                _SortChip(
                  label: 'Tất cả',
                  selected: currentPeriod == SearchPeriod.alltime,
                  onTap: () => onPeriodChanged(SearchPeriod.alltime),
                ),
                _SortChip(
                  label: '7 ngày',
                  selected: currentPeriod == SearchPeriod.d7,
                  onTap: () => onPeriodChanged(SearchPeriod.d7),
                ),
                _SortChip(
                  label: '30 ngày',
                  selected: currentPeriod == SearchPeriod.d30,
                  onTap: () => onPeriodChanged(SearchPeriod.d30),
                ),
                _SortChip(
                  label: '1 năm',
                  selected: currentPeriod == SearchPeriod.d365,
                  onTap: () => onPeriodChanged(SearchPeriod.d365),
                ),
              ],
            ),
          ],

          // ── Bán kính ─────────────────────────────────────────
          const SizedBox(height: 12),
          const _FilterLabel(label: 'Bán kính'),
          const SizedBox(height: 8),
          Row(
            children: [
              _SortChip(
                label: '5km',
                selected: currentRadius == 5 || currentRadius == null,
                onTap: () => onRadiusChanged(5),
              ),
              _SortChip(
                label: '10km',
                selected: currentRadius == 10,
                onTap: () => onRadiusChanged(10),
              ),
              _SortChip(
                label: '25km',
                selected: currentRadius == 25,
                onTap: () => onRadiusChanged(25),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String label;

  const _FilterLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9E9E9E),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8472A) : const Color(0xFFF5F5F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? const Color(0xFFE8472A) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }
}