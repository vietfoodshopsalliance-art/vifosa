// lib/features/store_dashboard/settings/open_hours_editor.dart

import 'package:flutter/material.dart';

const _dayLabels = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
const _dayKeys  = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

// ─── Model ────────────────────────────────────────────────────────────────────

class DayHours {
  final bool closed;
  final String open;
  final String close;

  const DayHours({
    this.closed = false,
    this.open   = '08:00',
    this.close  = '22:00',
  });

  DayHours copyWith({bool? closed, String? open, String? close}) => DayHours(
        closed: closed ?? this.closed,
        open:   open   ?? this.open,
        close:  close  ?? this.close,
      );

  Map<String, dynamic> toJson() =>
      closed ? {'closed': true} : {'open': open, 'close': close};

  factory DayHours.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DayHours();
    if (json['closed'] == true) return const DayHours(closed: true);
    return DayHours(
      open:  json['open']  as String? ?? '08:00',
      close: json['close'] as String? ?? '22:00',
    );
  }
}

// ─── Editor widget ────────────────────────────────────────────────────────────

class OpenHoursEditor extends StatefulWidget {
  final Map<String, DayHours> initialValue;
  final ValueChanged<Map<String, DayHours>> onChanged;

  const OpenHoursEditor({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<OpenHoursEditor> createState() => _OpenHoursEditorState();
}

class _OpenHoursEditorState extends State<OpenHoursEditor> {
  late Map<String, DayHours> _hours;

  @override
  void initState() {
    super.initState();
    _hours = {
      for (final k in _dayKeys)
        k: widget.initialValue[k] ?? const DayHours(),
    };
  }

  void _update(String key, DayHours value) {
    setState(() => _hours[key] = value);
    widget.onChanged(Map.unmodifiable(_hours));
  }

  @override
  Widget build(BuildContext context) {
    // Wrap trong Card để tự có bounded width bất kể parent là gì
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _dayKeys.length; i++) ...[
            _DayRow(
              label:    _dayLabels[i],
              hours:    _hours[_dayKeys[i]]!,
              onChanged: (v) => _update(_dayKeys[i], v),
            ),
            if (i < _dayKeys.length - 1)
              Divider(height: 1, indent: 16, endIndent: 16,
                  color: Theme.of(context).colorScheme.outlineVariant),
          ],
        ],
      ),
    );
  }
}

// ─── Row cho 1 ngày ──────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final String label;
  final DayHours hours;
  final ValueChanged<DayHours> onChanged;

  const _DayRow({
    required this.label,
    required this.hours,
    required this.onChanged,
  });

  Future<void> _pickTime(BuildContext context, bool isOpen) async {
    final parts = (isOpen ? hours.open : hours.close).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour:   int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final s = '${picked.hour.toString().padLeft(2, '0')}:'
              '${picked.minute.toString().padLeft(2, '0')}';
    onChanged(isOpen ? hours.copyWith(open: s) : hours.copyWith(close: s));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Tên ngày — fixed width
          SizedBox(
            width: 68,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),

          // Toggle mở/đóng
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: !hours.closed,
              activeColor: theme.colorScheme.primary,
              onChanged: (v) => onChanged(hours.copyWith(closed: !v)),
            ),
          ),

          // Giờ mở/đóng hoặc label "Đóng"
          Expanded(
            child: hours.closed
                ? Text('Đóng cả ngày',
                    style: TextStyle(
                        color: theme.colorScheme.outline, fontSize: 13))
                : Row(
                    children: [
                      Expanded(
                        child: _TimeButton(
                          time: hours.open,
                          onTap: () => _pickTime(context, true),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('–',
                            style: TextStyle(
                                color: theme.colorScheme.outline,
                                fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: _TimeButton(
                          time: hours.close,
                          onTap: () => _pickTime(context, false),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Nút giờ ─────────────────────────────────────────────────────────────────

class _TimeButton extends StatelessWidget {
  final String time;
  final VoidCallback onTap;

  const _TimeButton({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(6),
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        ),
        alignment: Alignment.center,
        child: Text(
          time,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// lib/features/store_dashboard/settings/open_hours_editor.dart