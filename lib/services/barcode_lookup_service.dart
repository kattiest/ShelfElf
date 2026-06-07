import 'dart:convert';
import 'package:http/http.dart' as http;

class BarcodeLookupService {
  BarcodeLookupService._();
  static final BarcodeLookupService instance = BarcodeLookupService._();

  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v0/product';

  /// Look up a product by UPC barcode using the Open Food Facts API.
  ///
  /// Returns the product name string, or `null` if not found or on error.
  Future<String?> lookupProduct(String upc) async {
    if (upc.isEmpty) return null;

    final uri = Uri.parse('$_baseUrl/$upc.json');

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'PantryPal/1.0 (Flutter)'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // status == 1 means product was found
      final status = json['status'];
      if (status != 1) return null;

      final product = json['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      // Prefer the generic product name, fall back to brand + product
      final name = product['product_name'] as String?;
      if (name != null && name.isNotEmpty) return name;

      final brands = product['brands'] as String?;
      final genericName = product['generic_name'] as String?;

      if (brands != null && brands.isNotEmpty) {
        if (genericName != null && genericName.isNotEmpty) {
          return '$brands – $genericName';
        }
        return brands;
      }

      return genericName?.isNotEmpty == true ? genericName : null;
    } catch (_) {
      return null;
    }
  }
}
