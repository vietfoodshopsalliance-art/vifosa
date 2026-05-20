// lib/features/profile/screens/edit_profile_screen.dart
// Sửa: initState dùng ref.read đúng cách, user.field thay user['field']

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_providers.dart';
import '../../../shared/utils/cloudinary_upload.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nicknameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // ← ĐÃ SỬA: dùng ref.read(authProvider).user thay vì user?['nickname']
    final user = ref.read(authProvider).user;
    _nicknameCtrl.text = user?['nickname'] as String? ?? '';
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    setState(() => _loading = true);
    try {
      final url = await CloudinaryUpload.uploadImage(
        filePath: file.path,
        folder: 'avatars',
        transformation: 'w_400,h_400,c_fill,g_face,f_auto,q_auto',
      );
      await ref.read(profileRepositoryProvider).updateAvatar(url);
      ref.invalidate(authProvider);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(profileRepositoryProvider).updateMe({
        'nickname': _nicknameCtrl.text.trim(),
      });
      ref.invalidate(authProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user; // ← watch ở build, read ở initState
    final avatarUrl = user?['avatarImage'] as String?;
    final nickname = user?['nickname'] as String? ?? 'U';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('Lưu'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  nickname.isNotEmpty ? nickname[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 32),
                                )
                              : null,
                        ),
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.orange,
                            child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Tên hiển thị', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nicknameCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Nhập tên hiển thị',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tên tài khoản (username) không thể thay đổi.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
    );
  }
}