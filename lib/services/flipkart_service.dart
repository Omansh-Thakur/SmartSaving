import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import '../models/product.dart';
import 'api_config.dart';

class FlipkartService {
  static const List<Map<String, dynamic>> mockProducts = [
    {
      'id': 'prod_001',
      'name': 'Apple iPhone 15 Pro',
      'category': 'Smartphones',
      'basePrice': 79999,
      'discount': 0.08,
      'image':
          'https://images.unsplash.com/photo-1592286927505-1def25115558?w=300&h=300&fit=crop',
    },
    {
      'id': 'prod_002',
      'name': 'Samsung Galaxy S24',
      'category': 'Smartphones',
      'basePrice': 74999,
      'discount': 0.10,
      'image':
          'https://images.unsplash.com/photo-1511707267537-b85faf00021e?w=300&h=300&fit=crop',
    },
    {
      'id': 'prod_003',
      'name': 'Sony WH-1000XM5 Headphones',
      'category': 'Audio',
      'basePrice': 22999,
      'discount': 0.18,
      'image':
          'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=300&h=300&fit=crop',
    },
    {
      'id': 'prod_004',
      'name': 'Dell XPS 13 Laptop',
      'category': 'Computers',
      'basePrice': 99999,
      'discount': 0.12,
      'image':
          'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=300&h=300&fit=crop',
    },
    {
      'id': 'prod_005',
      'name': 'iPad Air 2024',
      'category': 'Tablets',
      'basePrice': 59999,
      'discount': 0.09,
      'image':
          'https://images.unsplash.com/photo-1561070791-2526d30994b5?w=300&h=300&fit=crop',
    },
    {
      'id': 'prod_006',
      'name': 'Apple Watch Series 9',
      'category': 'Wearables',
      'basePrice': 34999,
      'discount': 0.08,
      'image':
          'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=300&h=300&fit=crop',
    },
    {
      'id': 'prod_007',
      'name': 'Canon EOS R6 Camera',
      'category': 'Cameras',
      'basePrice': 189999,
      'discount': 0.07,
      'image':
          'https://images.unsplash.com/photo-1617638924702-92f37fcb18ad?w=300&h=300&fit=crop',
    },
    {
      'id': 'prod_008',
      'name': 'LG 55" 4K Smart TV',
      'category': 'TVs',
      'basePrice': 49999,
      'discount': 0.15,
      'image':
          'https://images.unsplash.com/photo-1598327318881-a07a7fbb4e50?w=300&h=300&fit=crop',
    },
  ];

  /// Search products on Flipkart using real API
  Future<List<Product>> searchProducts(String query) async {
    if (query.isEmpty) {
      print('⚠️  Empty search query');
      return _getMockProducts();
    }

    try {
      print('🔍 Searching Flipkart for: $query');
      final uri = Uri.parse(
        ApiConfig.flipkartApiUrl,
      ).replace(queryParameters: {'q': query, 'country': 'IN'});

      final response = await http
          .get(uri, headers: ApiConfig.flipkartHeaders)
          .timeout(const Duration(seconds: ApiConfig.requestTimeout));

      print('Response Status: ${response.statusCode}');
      print('Response Body Length: ${response.body.length} chars');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ [FLIPKART] Got response: ${data.runtimeType}');
        final results = _parseFlipkartResponse(data);
        if (results.isNotEmpty) {
          print('✅ [FLIPKART] Returning ${results.length} products');
          return results;
        } else {
          print('⚠️  [FLIPKART] No products parsed, using mock');
          return _getMockProducts();
        }
      } else {
        print('❌ [FLIPKART] Error ${response.statusCode} - using mock');
        return _getMockProducts();
      }
    } catch (e) {
      print('❌ [FLIPKART] Exception: $e - using mock products');
      print('FALLBACK: Returning mock products');
      return _getMockProducts();
    }
  }

  /// Get single product details from Flipkart
  Future<Product?> getProduct(String productId) async {
    try {
      print('📦 Getting Flipkart product: $productId');
      final uri = Uri.parse(
        ApiConfig.flipkartApiUrl,
      ).replace(queryParameters: {'id': productId});

      final response = await http
          .get(uri, headers: ApiConfig.flipkartHeaders)
          .timeout(const Duration(seconds: ApiConfig.requestTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? [];
        if (results.isNotEmpty) {
          return _parseProductFromApi(results.first);
        }
      }
      return null;
    } catch (e) {
      print('❌ Get product error: $e');
      return null;
    }
  }

  /// Get current price from Flipkart
  Future<double> getCurrentPrice(String productId) async {
    try {
      final product = await getProduct(productId);
      return product?.flipkartPrice ?? 0.0;
    } catch (e) {
      print('❌ Get price error: $e');
      return 0.0;
    }
  }

  /// Parse Flipkart API response
  List<Product> _parseFlipkartResponse(dynamic data) {
    final results = <Product>[];
    try {
      print('🔍 Looking for results key in Flipkart response...');

      // Try different possible response structures
      List? items = data['results'] as List?;
      if (items == null) {
        print('⚠️  No "results" key found');
        items = data['data'] as List?;
      }
      if (items == null) {
        items = data['products'] as List?;
      }
      if (items == null && data is List) {
        items = data;
      }

      items ??= [];
      print('📦 Found ${items.length} items to parse');
      print(
        'First item (if exists): ${items.isNotEmpty ? items.first : "EMPTY"}',
      );

      for (var item in items) {
        final product = _parseProductFromApi(item);
        if (product != null) {
          results.add(product);
        }
      }
      print('✅ Parsed ${results.length} products from Flipkart');
    } catch (e, st) {
      print('❌ Parse error: $e');
      print('Stack: $st');
    }
    return results.isNotEmpty ? results : _getMockProducts();
  }

  /// Parse single product from API response
  Product? _parseProductFromApi(dynamic item) {
    try {
      // Debug: show available keys
      if (item is Map) {
        print('📌 Item keys: ${(item as Map).keys.toList()}');
      }

      // Get image URL - try multiple possible field names
      String imageUrl = '';
      if (item['image'] != null) {
        imageUrl = item['image'].toString();
      } else if (item['thumbnail'] != null) {
        imageUrl = item['thumbnail'].toString();
      } else if (item['imageUrl'] != null) {
        imageUrl = item['imageUrl'].toString();
      } else if (item['productImage'] != null) {
        imageUrl = item['productImage'].toString();
      }

      // If no image from API, use placeholder
      if (imageUrl.isEmpty) {
        final productName =
            item['title']?.toString() ?? item['name']?.toString() ?? 'Product';
        imageUrl =
            'https://via.placeholder.com/300x300?text=${Uri.encodeComponent(productName)}';
      }

      return Product(
        id: item['id']?.toString() ?? item['asin']?.toString() ?? 'unknown',
        name:
            item['title']?.toString() ?? item['name']?.toString() ?? 'Unknown',
        description:
            item['description']?.toString() ??
            item['productDescription']?.toString() ??
            'No description',
        imageUrl: imageUrl,
        amazonPrice:
            (item['price'] as num?)?.toDouble() ??
            (item['currentPrice'] as num?)?.toDouble() ??
            (item['offerPrice'] as num?)?.toDouble() ??
            (item['discountedPrice'] as num?)?.toDouble() ??
            0.0,
        flipkartPrice: (item['price'] as num?)?.toDouble() ?? 0.0,
        rating:
            (item['rating'] as num?)?.toDouble() ??
            (item['stars'] as num?)?.toDouble() ??
            (item['productRating'] as num?)?.toDouble() ??
            0.0,
        reviews:
            item['reviews'] as int? ??
            item['numOfRatings'] as int? ??
            item['reviewCount'] as int? ??
            0,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print(
        '❌ Parse product error: $e, item keys: ${item is Map ? (item as Map).keys.toList() : "not a map"}',
      );
      return null;
    }
  }

  /// Get mock products as fallback
  List<Product> _getMockProducts() {
    return mockProducts.map((data) => _createProduct(data)).toList();
  }

  Product _createProduct(Map<String, dynamic> data) {
    final basePrice = data['basePrice'] as int;
    final discount = data['discount'] as double;
    final actualPrice = (basePrice * (1 - discount)).toDouble();
    final imageUrl = data['image'] as String?;

    return Product(
      id: data['id'] as String,
      name: data['name'] as String,
      description:
          'Exclusive ${data['category']} with great deals and fast delivery',
      imageUrl:
          imageUrl ??
          'https://via.placeholder.com/300x300?text=${Uri.encodeComponent(data["name"])}',
      amazonPrice: actualPrice + Random().nextDouble() * 3000,
      flipkartPrice: actualPrice + Random().nextDouble() * 5000,
      rating: 3.8 + Random().nextDouble() * 1.2,
      reviews: Random().nextInt(4000) + 200,
      updatedAt: DateTime.now(),
    );
  }
}

final flipkartService = FlipkartService();
