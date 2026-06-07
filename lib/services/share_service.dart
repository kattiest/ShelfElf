import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import '../models/food_item.dart';

/// Encodes a shopping list into a deep link URL and shares it.
/// The list is serialised as JSON, base64-encoded, and embedded in the URL:
///   pantrypal://list/<base64>
///
/// No server required — all data travels in the link itself.
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  static const _scheme = 'pantrypal';
  static const _host = 'list';

  /// Encode [items] into a shareable deep-link URL string.
  String encodeList(List<FoodItem> items) {
    final data = items
        .map((i) => {
              'p': i.product,
              'l': i.location,
              'r': i.percentRemaining,
            })
        .toList();

    final json = jsonEncode(data);
    // Use URL-safe base64 so the link survives SMS/WhatsApp encoding
    final encoded = base64Url.encode(utf8.encode(json));
    return '$_scheme://$_host/$encoded';
  }

  /// Decode a deep-link URL back into a list of [SharedItem]s.
  /// Returns null if the URL is invalid or malformed.
  List<SharedItem>? decodeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != _scheme || uri.host != _host) return null;

      // Path is /<encoded>, strip the leading /
      final encoded = uri.pathSegments.first;
      final json = utf8.decode(base64Url.decode(encoded));
      final data = jsonDecode(json) as List<dynamic>;

      return data.map((e) {
        final map = e as Map<String, dynamic>;
        return SharedItem(
          product: map['p'] as String,
          location: map['l'] as String? ?? '',
          percentRemaining: (map['r'] as num).toInt(),
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// Share the shopping list via the system share sheet.
  Future<void> shareList(List<FoodItem> items, {String? senderName}) async {
    if (items.isEmpty) return;

    final url = encodeList(items);
    final names = items.map((i) => '• ${i.product}').join('\n');
    final intro = senderName != null
        ? '$senderName shared a PantryPal shopping list with you:'
        : 'Here\'s a PantryPal shopping list:';

    final message = '$intro\n\n$names\n\nTap to import:\n$url';

    await Share.share(message);
  }
}

/// A lightweight item decoded from a shared link — not a full FoodItem.
class SharedItem {
  final String product;
  final String location;
  final int percentRemaining;

  const SharedItem({
    required this.product,
    required this.location,
    required this.percentRemaining,
  });
}
