// lib/features/social/social_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_endpoints.dart';
import 'models/post_model.dart';
import 'models/comment_model.dart';

// -----
// Feed
// -----

class FeedState {
  final List<Post> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final String? error;

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.error,
  });

  FeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    String? error,
  }) =>
      FeedState(
        posts: posts ?? this.posts,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        error: error,
      );
}

class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier() : super(const FeedState()) {
    fetchFeed();
  }

  Future<void> fetchFeed() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await DioClient().dio.get(
        ApiEndpoints.posts,
        queryParameters: {'page': 1, 'limit': 10},
      );
      final posts = (res.data as List)
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        posts: posts,
        isLoading: false,
        page: 1,
        hasMore: posts.length >= 10,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final res = await DioClient().dio.get(
        ApiEndpoints.posts,
        queryParameters: {'page': nextPage, 'limit': 10},
      );
      final newPosts = (res.data as List)
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        posts: [...state.posts, ...newPosts],
        isLoadingMore: false,
        page: nextPage,
        hasMore: newPosts.length >= 10,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> toggleLike(String postId) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final post = state.posts[idx];
    // Optimistic update
    final updated = post.copyWith(
      isLikedByMe: !post.isLikedByMe,
      likesCount: post.isLikedByMe ? post.likesCount - 1 : post.likesCount + 1,
    );
    final newList = [...state.posts];
    newList[idx] = updated;
    state = state.copyWith(posts: newList);
    try {
      await DioClient().dio.post(ApiEndpoints.postLike(postId));
    } catch (_) {
      // Rollback
      newList[idx] = post;
      state = state.copyWith(posts: [...newList]);
    }
  }

  Future<void> updatePost(String postId, Map<String, dynamic> body) async {
    await DioClient().dio.put(ApiEndpoints.postDetail(postId), data: body);
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final post = state.posts[idx];
    final newList = [...state.posts];
    newList[idx] = post.copyWith(
      isHidden: body['isHidden'] as bool? ?? post.isHidden,
      commentsDisabled:
          body['commentsDisabled'] as bool? ?? post.commentsDisabled,
    );
    state = state.copyWith(posts: newList);
  }

  Future<void> deletePost(String postId) async {
    await DioClient().dio.delete(ApiEndpoints.postDetail(postId));
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != postId).toList(),
    );
  }

  void addPost(Post post) {
    state = state.copyWith(posts: [post, ...state.posts]);
  }
}

final feedProvider =
    StateNotifierProvider<FeedNotifier, FeedState>((ref) => FeedNotifier());

// ---------------------------------------------------------------------------
// Post detail
// ---------------------------------------------------------------------------

final postDetailProvider =
    FutureProvider.family<Post, String>((ref, postId) async {
  final res =
      await DioClient().dio.get(ApiEndpoints.postDetail(postId));
  return Post.fromJson(res.data as Map<String, dynamic>);
});

// ---------------------------------------------------------------------------
// Comments
// ---------------------------------------------------------------------------

class CommentsState {
  final List<Comment> comments;
  final bool isLoading;
  final String? error;

  const CommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.error,
  });

  CommentsState copyWith({
    List<Comment>? comments,
    bool? isLoading,
    String? error,
  }) =>
      CommentsState(
        comments: comments ?? this.comments,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class CommentsNotifier extends StateNotifier<CommentsState> {
  final String postId;

  CommentsNotifier(this.postId) : super(const CommentsState()) {
    fetchComments();
  }

  Future<void> fetchComments() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await DioClient()
          .dio
          .get(ApiEndpoints.postComments(postId));
      // Build tree: top-level comments + replies
      final all = (res.data as List)
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList();
      final topLevel = all.where((c) => c.parentId == null).toList();
      state = state.copyWith(comments: topLevel, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addComment(String content, {String? parentId}) async {
    final res = await DioClient().dio.post(
      ApiEndpoints.postComments(postId),
      data: {'content': content, if (parentId != null) 'parentId': parentId},
    );
    final newComment =
        Comment.fromJson(res.data as Map<String, dynamic>);
    if (parentId == null) {
      state = state.copyWith(comments: [...state.comments, newComment]);
    } else {
      final newList = state.comments.map((c) {
        if (c.id == parentId) {
          return Comment(
            id: c.id,
            postId: c.postId,
            parentId: c.parentId,
            userId: c.userId,
            nickname: c.nickname,
            avatarUrl: c.avatarUrl,
            content: c.content,
            likesCount: c.likesCount,
            isLikedByMe: c.isLikedByMe,
            isOwnComment: c.isOwnComment,
            replies: [...c.replies, newComment],
            createdAt: c.createdAt,
          );
        }
        return c;
      }).toList();
      state = state.copyWith(comments: newList);
    }
  }

  Future<void> toggleLikeComment(String commentId,
      {String? parentId}) async {
    Comment? update(Comment c) {
      if (c.id == commentId) {
        return c.copyWith(
          isLikedByMe: !c.isLikedByMe,
          likesCount:
              c.isLikedByMe ? c.likesCount - 1 : c.likesCount + 1,
        );
      }
      return null;
    }

    final snapshot = [...state.comments];

    List<Comment> applyOptimistic(List<Comment> list) => list.map((c) {
          final updated = update(c);
          if (updated != null) return updated;
          final newReplies = c.replies.map((r) {
            final u = update(r);
            return u ?? r;
          }).toList();
          return Comment(
            id: c.id,
            postId: c.postId,
            parentId: c.parentId,
            userId: c.userId,
            nickname: c.nickname,
            avatarUrl: c.avatarUrl,
            content: c.content,
            likesCount: c.likesCount,
            isLikedByMe: c.isLikedByMe,
            isOwnComment: c.isOwnComment,
            replies: newReplies,
            createdAt: c.createdAt,
          );
        }).toList();

    state = state.copyWith(comments: applyOptimistic(state.comments));
    try {
      await DioClient()
          .dio
          .post(ApiEndpoints.commentLike(postId, commentId));
    } catch (_) {
      state = state.copyWith(comments: snapshot);
    }
  }
}

final postCommentsProvider = StateNotifierProvider.family<CommentsNotifier,
    CommentsState, String>(
  (ref, postId) => CommentsNotifier(postId),
);
