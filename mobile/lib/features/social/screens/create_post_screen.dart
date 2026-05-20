// lib/features/social/create_post_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/image_service.dart';
import '../../../features/social/social_provider.dart';
import '../../../features/social/models/post_model.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  final List<File> _selectedImages = [];

  String? _taggedStoreId;
  String? _taggedStoreName;
  String? _taggedItemId;
  String? _taggedItemName;
  String _visibility = 'public';

  bool _isPosting = false;
  int _uploadProgress = 0;

  static const int _maxImages = 5;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  bool get _canPost =>
      !_isPosting &&
      (_selectedImages.isNotEmpty ||
          _captionController.text.trim().isNotEmpty);

  Future<void> _pickImage() async {
  if (_selectedImages.length >= _maxImages) return;
  final xfile = await ImageService.instance.pickSingle();
  if (xfile != null) {
    setState(() => _selectedImages.add(File(xfile.path)));
  }
}

  Future<void> _post() async {
    if (!_canPost) return;
    setState(() {
      _isPosting = true;
      _uploadProgress = 0;
    });

    try {
      final urls = <String>[];
for (var i = 0; i < _selectedImages.length; i++) {
  setState(() => _uploadProgress = i + 1);
  final uploaded = await ImageService.instance.uploadFile(
    _selectedImages[i],
    context: ImageUploadContext.post,
  );
  urls.add(uploaded.url);
}

      final res = await DioClient.instance.post(
        ApiEndpoints.posts,
        data: {
          'images': urls,
          'caption': _captionController.text.trim(),
          if (_taggedStoreId != null) 'taggedStoreId': _taggedStoreId,
          if (_taggedItemId != null) 'taggedItemId': _taggedItemId,
          'visibility': _visibility,
        },
      );

      final newPost = Post.fromJson(res.data as Map<String, dynamic>);
      ref.read(feedProvider.notifier).addPost(newPost);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng thất bại: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _searchAndTagStore() async {
    final result = await showSearch<Map<String, String>?>(
      context: context,
      delegate: _StoreSearchDelegate(),
    );
    if (result != null) {
      setState(() {
        _taggedStoreId = result['id'];
        _taggedStoreName = result['name'];
      });
    }
  }

  Future<void> _searchAndTagItem() async {
    final result = await showSearch<Map<String, String>?>(
      context: context,
      delegate: _ItemSearchDelegate(),
    );
    if (result != null) {
      setState(() {
        _taggedItemId = result['id'];
        _taggedItemName = result['name'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        title: const Text('Tạo bài viết'),
        actions: [
          TextButton(
            onPressed: _canPost ? _post : null,
            child: _isPosting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Đăng',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload progress
            if (_isPosting)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đang tải ảnh... ($_uploadProgress/${_selectedImages.length})',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _selectedImages.isEmpty
                          ? 0
                          : _uploadProgress / _selectedImages.length,
                    ),
                  ],
                ),
              ),

            // Image grid picker
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_selectedImages.length < _maxImages)
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 90,
                        height: 90,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[50],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 28, color: Colors.grey),
                            SizedBox(height: 4),
                            Text('Thêm ảnh',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ..._selectedImages.asMap().entries.map((e) {
                    final idx = e.key;
                    final file = e.value;
                    return Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(file),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 10,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedImages.removeAt(idx)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Caption
            TextField(
              controller: _captionController,
              decoration: InputDecoration(
                hintText: 'Viết caption...',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              maxLines: 6,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // Tag section
            const Text('Gắn thẻ',
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            _TagRow(
              icon: '🏪',
              label: _taggedStoreName ?? 'Tag quán',
              hasValue: _taggedStoreName != null,
              onTap: _searchAndTagStore,
              onClear: () => setState(() {
                _taggedStoreId = null;
                _taggedStoreName = null;
              }),
            ),
            const SizedBox(height: 8),
            _TagRow(
              icon: '🍜',
              label: _taggedItemName ?? 'Tag món',
              hasValue: _taggedItemName != null,
              onTap: _searchAndTagItem,
              onClear: () => setState(() {
                _taggedItemId = null;
                _taggedItemName = null;
              }),
            ),
            const SizedBox(height: 20),

            // Visibility
            const Text('Hiển thị',
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public')),
                DropdownMenuItem(
                    value: 'private', child: Text('Chỉ mình tôi')),
              ],
              onChanged: (v) => setState(() => _visibility = v!),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tag row helper
// ---------------------------------------------------------------------------

class _TagRow extends StatelessWidget {
  final String icon;
  final String label;
  final bool hasValue;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _TagRow({
    required this.icon,
    required this.label,
    required this.hasValue,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: hasValue
                      ? Colors.black87
                      : Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ),
            if (hasValue)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 18, color: Colors.grey),
              )
            else
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder search delegates — wire to actual API
// ---------------------------------------------------------------------------

class _StoreSearchDelegate
    extends SearchDelegate<Map<String, String>?> {
  @override
  List<Widget> buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) =>
      _SearchResultsList(query: query, onSelect: (r) => close(context, r));

  @override
  Widget buildSuggestions(BuildContext context) =>
      _SearchResultsList(query: query, onSelect: (r) => close(context, r));
}

class _ItemSearchDelegate extends SearchDelegate<Map<String, String>?> {
  @override
  List<Widget> buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) =>
      _SearchResultsList(query: query, onSelect: (r) => close(context, r));

  @override
  Widget buildSuggestions(BuildContext context) =>
      _SearchResultsList(query: query, onSelect: (r) => close(context, r));
}

class _SearchResultsList extends StatefulWidget {
  final String query;
  final void Function(Map<String, String>) onSelect;

  const _SearchResultsList(
      {required this.query, required this.onSelect});

  @override
  State<_SearchResultsList> createState() => _SearchResultsListState();
}

class _SearchResultsListState extends State<_SearchResultsList> {
  List<Map<String, String>> _results = [];
  bool _loading = false;

  @override
  void didUpdateWidget(_SearchResultsList old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _search();
  }

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    if (widget.query.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await DioClient.instance
          .get('/search', queryParameters: {'q': widget.query});
      final items = (res.data as List).map((e) {
        final m = e as Map<String, dynamic>;
        return {'id': m['id'] as String, 'name': m['name'] as String};
      }).toList();
      if (mounted) setState(() => _results = items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return const Center(child: Text('Không tìm thấy kết quả'));
    }
    return ListView(
      children: _results
          .map((r) => ListTile(
                title: Text(r['name']!),
                onTap: () => widget.onSelect(r),
              ))
          .toList(),
    );
  }
}
