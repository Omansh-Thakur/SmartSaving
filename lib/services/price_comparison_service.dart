import 'dart:math';
import '../models/product.dart';
import 'amazon_service.dart';
import 'flipkart_service.dart';

class PriceComparisonService {
  Future<Product> comparePrice(String productId) async {
    final amazonFuture = amazonService.getCurrentPrice(productId);
    final flipkartFuture = flipkartService.getCurrentPrice(productId);

    final [amazonPrice, flipkartPrice] = await Future.wait([
      amazonFuture,
      flipkartFuture,
    ]);

    // Get product details from amazon
    final product = await amazonService.getProduct(productId);

    if (product == null) {
      throw Exception('Product not found');
    }

    return Product(
      id: product.id,
      name: product.name,
      description: product.description,
      imageUrl: product.imageUrl,
      amazonPrice: amazonPrice,
      flipkartPrice: flipkartPrice,
      rating: product.rating,
      reviews: product.reviews,
      updatedAt: DateTime.now(),
    );
  }

  Future<List<Product>> comparePriceForProducts(List<String> productIds) async {
    final futures = productIds.map((id) => comparePrice(id));
    return Future.wait(futures);
  }
}

final priceComparisonService = PriceComparisonService();
