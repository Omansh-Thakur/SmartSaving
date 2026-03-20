import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/amazon_service.dart';
import '../services/flipkart_service.dart';
import '../models/product.dart';

final amazonServiceProvider = Provider((ref) => amazonService);
final flipkartServiceProvider = Provider((ref) => flipkartService);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() {
    return 'Popular';
  }

  void setQuery(String query) {
    state = query;
  }
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

final productsProvider =
    NotifierProvider<ProductsNotifier, AsyncValue<List<Product>>>(() {
  return ProductsNotifier();
});

class ProductsNotifier extends Notifier<AsyncValue<List<Product>>> {
  late String query;

  @override
  AsyncValue<List<Product>> build() {
    query = ref.watch(searchQueryProvider);
    _searchProducts();
    return const AsyncValue.loading();
  }

  Future<void> _searchProducts() async {
    // If query is empty, show all mock products
    if (query.trim().isEmpty) {
      print('⚠️  Empty query - showing all mock products');
      final mockProducts = await amazonService.searchProducts('Popular');
      state = AsyncValue.data(mockProducts);
      return;
    }

    state = const AsyncValue.loading();
    try {
      print('🔍 Provider searching for: $query');
      final amazonResults = await amazonService.searchProducts(query);
      print('📊 Got ${amazonResults.length} results from Amazon');

      if (amazonResults.isEmpty) {
        print('⚠️  No results found, check API console logs');
      }
      state = AsyncValue.data(amazonResults);
    } catch (e, st) {
      print('❌ Provider search error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> retry() => _searchProducts();
}

final productDetailProvider = FutureProvider.family<Product?, String>((
  ref,
  productId,
) async {
  try {
    return await amazonService.getProduct(productId);
  } catch (e) {
    return null;
  }
});

final priceComparisonProvider = FutureProvider.family<Product, String>((
  ref,
  productId,
) async {
  const detailRequestTimeout = Duration(seconds: 8);
  final amazonFuture = amazonService.getCurrentPrice(productId).timeout(
        detailRequestTimeout,
        onTimeout: () => 0.0,
      );
  final flipkartFuture = flipkartService.getCurrentPrice(productId).timeout(
        detailRequestTimeout,
        onTimeout: () => 0.0,
      );

  final results = await Future.wait([amazonFuture, flipkartFuture]);
  final amazonPrice = results[0] as double;
  final flipkartPrice = results[1] as double;

  final product = await amazonService.getProduct(productId).timeout(
        detailRequestTimeout,
        onTimeout: () => null,
      );
  if (product == null) {
    throw Exception('Unable to load product details');
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
});
