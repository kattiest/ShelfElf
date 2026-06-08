import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import '../models/food_item.dart';

/// Encodes a shopping list into a shareable https:// link.
///
/// The link points to a GitHub Pages redirect page which immediately
/// opens the app via the pantrypal:// deep link scheme.
/// Using https:// means SMS/WhatsApp renders it as a tappable link.
///
/// Format: https://kattiest.github.io/ShelfElf/?list=<base64>
/// Which redirects to: pantrypal://list/<base64>
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  static const _webBase = 'https://kattiest.github.io/ShelfElf/';
  static const _appScheme = 'pantrypal';
  static const _appHost = 'list';

  /// Encode [items] into a shareable https link.
  String encodeList(List<FoodItem> items) {
    final data = items
        .map((i) => {
              'p': i.product,
              'l': i.location,
              'r': i.percentRemaining,
            })
        .toList();

    final json = jsonEncode(data);
    final encoded = base64Url.encode(utf8.encode(json));
    return '$_webBase?list=$encoded';
  }

  /// Decode either a https web link or a pantrypal:// deep link.
  List<SharedItem>? decodeUrl(String url) {
    try {
      final uri = Uri.parse(url);

      String? encoded;

      if (uri.scheme == 'https' && uri.queryParameters.containsKey('list')) {
        // Web redirect link: https://kattiest.github.io/ShelfElf/?list=xxx
        encoded = uri.queryParameters['list'];
      } else if (uri.scheme == _appScheme && uri.host == _appHost) {
        // Legacy direct deep link: pantrypal://list/xxx
        encoded = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }

      if (encoded == null || encoded.isEmpty) return null;

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
    final count = items.length;

    // Show a clean preview — the URL is embedded, not shown raw
    final intro = senderName != null
        ? '$senderName sent you a Shelf Elf shopping list'
        : 'Shelf Elf Shopping List';

    // The message body is just the title + item count
    // The URL renders as a rich card in iMessage/WhatsApp
    final message = '$intro — $count item${count == 1 ? '' : 's'}\n$url';

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
