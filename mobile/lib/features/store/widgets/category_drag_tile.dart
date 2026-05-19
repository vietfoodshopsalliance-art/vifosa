// lib/features/store/widgets/category_drag_tile.dart

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Model nhẹ dùng trong widget — mapping từ entity Category của domain
// ---------------------------------------------------------------------------

class CategoryDragItem {
  final String id;
  final String name;
  final int itemCount; // số món trong danh mục

  const CategoryDragItem({
    required this.id,
    required this.name,
    required this.itemCount,
  });
}

// ---------------------------------------------------------------------------
// Widget chính
// ---------------------------------------------------------------------------

/// Tile danh mục dùng trong ReorderableListView của màn hình quản lý menu.
///
/// Hiển thị: tên danh mục + số món + drag handle + menu (sửa / xóa).
/// Khi [isEditing] = true → ẩn actions, chỉ hiện TextField đổi tên.
class CategoryDragTile extends StatefulWidget {
  final CategoryDragItem category;
  final bool isEditing;
  final VoidCallback onTap; // mở rộng / thu gọn danh sách món bên dưới
  final VoidCallback onEditStart;
  final ValueChanged<String> onEditDone; // tên mới sau khi xác nhận
  final VoidCallback onEditCancel;
  final VoidCallback onDelete;

  const CategoryDragTile({
    super.key,
    required this.category,
    required this.isEditing,
    required this.onTap,
    required this.onEditStart,
    required this.onEditDone,
    required this.onEditCancel,
    required this.onDelete,
  });

  @override
  State<CategoryDragTile> createState() => _CategoryDragTileState();
}

class _CategoryDragTileState extends State<CategoryDragTile> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.category.name);
  }

  @override
  void didUpdateWidget(CategoryDragTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Đồng bộ tên khi widget rebuild với dữ liệu mới
    if (oldWidget.category.name != widget.category.name && !widget.isEditing) {
      _ctrl.text = widget.category.name;
    }
    // Khi bắt đầu edit, select-all để dễ thay thế tên
    if (!oldWidget.isEditing && widget.isEditing) {
      _ctrl
        ..text = widget.category.name
        ..selection =
            TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirmEdit() {
    final trimmed = _ctrl.text.trim();
    if (trimmed.isEmpty) {
      widget.onEditCancel();
      return;
    }
    widget.onEditDone(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: InkWell(
        onTap: widget.isEditing ? null : widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Drag handle — ReorderableListView nhận gesture qua key này
              ReorderableDragStartListener(
                index: 0, // index thật do ReorderableListView truyền vào key
                child: Icon(
                  Icons.drag_handle,
                  color: colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),

              // Tên danh mục (hiển thị hoặc TextField khi đang edit)
              Expanded(
                child: widget.isEditing
                    ? _buildTextField(context)
                    : _buildLabel(context),
              ),

              // Actions hoặc confirm/cancel khi edit
              if (widget.isEditing)
                _buildEditActions()
              else
                _buildMenuButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Flexible(
          child: Text(
            widget.category.name,
            style: textTheme.titleSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '(${widget.category.itemCount} món)',
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(BuildContext context) {
    return TextField(
      controller: _ctrl,
      autofocus: true,
      style: Theme.of(context).textTheme.titleSmall,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: OutlineInputBorder(),
      ),
      onSubmitted: (_) => _confirmEdit(),
      textInputAction: TextInputAction.done,
    );
  }

  Widget _buildEditActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Huỷ
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          tooltip: 'Huỷ',
          onPressed: widget.onEditCancel,
          visualDensity: VisualDensity.compact,
        ),
        // Xác nhận
        IconButton(
          icon: const Icon(Icons.check, size: 20),
          tooltip: 'Lưu',
          onPressed: _confirmEdit,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return PopupMenuButton<_Action>(
      icon: const Icon(Icons.more_vert, size: 20),
      tooltip: 'Tuỳ chọn',
      onSelected: (action) {
        switch (action) {
          case _Action.edit:
            widget.onEditStart();
          case _Action.delete:
            _confirmDelete(context);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _Action.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Đổi tên'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: _Action.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Xoá danh mục', style: TextStyle(color: Colors.red)),
            dense: true,
          ),
        ),
      ],
    );
  }

  // Confirm dialog trước khi xóa — tránh xóa nhầm khi còn món bên trong
  Future<void> _confirmDelete(BuildContext context) async {
    final hasItems = widget.category.itemCount > 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá danh mục?'),
        content: Text(
          hasItems
              ? 'Danh mục "${widget.category.name}" còn ${widget.category.itemCount} món. '
                  'Xoá danh mục sẽ không xoá các món nhưng chúng sẽ không có danh mục.'
              : 'Xoá danh mục "${widget.category.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete();
  }
}

enum _Action { edit, delete }

// lib/features/store/widgets/category_drag_tile.dart