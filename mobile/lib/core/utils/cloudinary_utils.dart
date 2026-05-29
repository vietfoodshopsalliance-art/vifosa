// lib/core/utils/cloudinary_utils.dart

/// Inserts a Cloudinary transformation string into an existing URL.
/// Works for URLs from res.cloudinary.com only; other URLs are returned as-is.
///
/// Example:
///   input : https://res.cloudinary.com/dvubr3dwm/image/upload/v1/folder/img.jpg
///   output: https://res.cloudinary.com/dvubr3dwm/image/upload/f_auto,q_auto,w_800/v1/folder/img.jpg
String cloudinaryUrl(String? url, {String transform = 'f_auto,q_auto,w_800'}) {
  if (url == null || url.isEmpty) return '';
  if (!url.contains('res.cloudinary.com')) return url;
  return url.replaceFirst('/upload/', '/upload/$transform/');
}

/// 400 px — thumbnail lists, avatars
String cloudinaryThumb(String? url) =>
    cloudinaryUrl(url, transform: 'f_auto,q_auto,w_400');

/// 800 px — store detail carousel, full-size previews
String cloudinaryDetail(String? url) =>
    cloudinaryUrl(url, transform: 'f_auto,q_auto,w_800');
