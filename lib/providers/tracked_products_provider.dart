import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../models/tracked_product.dart';
import '../services/amazon_service.dart';
import '../services/flipkart_service.dart';
import '../services/notification_service.dart';
import '../services/price_history_generator_service.dart';
import '../services/storage_service.dart';
import '../services/tracking_api_service.dart';
import 'auth_provider.dart';

final trackedProductsProvider =
    NotifierProvider<TrackedProductsNotifier, AsyncValue<List<TrackedProduct>>>(() {
  return TrackedProductsNotifier();
});

class TrackedProductsNotifier extends Notifier<AsyncValue<List<TrackedProduct>>> {
  final _trackingData = <String, List<PriceSnapshot>>{};
  final _targetPrices = <String, double>{};
  final _lastPriceDropAlertDay = <String, DateTime>{};
  final _lastTargetAlertDay = <String, DateTime>{};

  @override
  AsyncValue<List<TrackedProduct>> build() {
    ref.watch(currentUserProvider); // Force reload on auth state shifts
    _loadTrackedProducts();
    return const AsyncValue.data([]);
  }

  Future<void> _loadTrackedProducts() async {
    try {
      final user = storageService.getUser();
      if (user != null) {
        // Fetch source of truth from backend database
        final remoteItems = await trackingApiService.getTrackedItems();
        final remoteIds = remoteItems.map((e) => e['product_id'] as String).toList();
        await storageService.saveTrackedProducts(remoteIds);
        
        for (var item in remoteItems) {
           final pid = item['product_id'];
           final price = item['target_price'];
           if (price != null) {
               await storageService.saveTargetPrice(pid, (price as num).toDouble());
           } else {
               await storageService.removeTargetPrice(pid);
           }
        }
      }

      final trackedIds = storageService.getTrackedProducts();
      _targetPrices
        ..clear()
        ..addAll(storageService.getAllTargetPrices());

      final trackedProducts = <TrackedProduct>[];
      for (final id in trackedIds) {
        final trackedProduct = await _buildTrackedProduct(id);
        if (trackedProduct != null) {
          trackedProducts.add(trackedProduct);
          await _evaluateAlerts(trackedProduct);
        }
      }

      state = AsyncValue.data(trackedProducts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<TrackedProduct?> _buildTrackedProduct(String productId) async {
    final baseProduct = await amazonService.getProduct(productId);
    if (baseProduct == null) return null;

    final storedHistory = storageService.getPriceHistory(productId);
    List<PriceSnapshot> history;

    if (storedHistory.isEmpty) {
      history = _generateInitialHistory(productId);
    } else {
      history = _normalizeAndRollHistory(productId, storedHistory);
    }

    if (history.isEmpty) {
      history = [
        PriceSnapshot(
          amazonPrice: baseProduct.amazonPrice,
          flipkartPrice: baseProduct.flipkartPrice,
          timestamp: DateTime.now(),
        ),
      ];
    }

    history = _trimHistory(history);
    _trackingData[productId] = history;
    await storageService.savePriceHistory(productId, history);

    final latestSnapshot = history.last;
    final product = Product(
      id: baseProduct.id,
      name: baseProduct.name,
      category: baseProduct.category,
      description: baseProduct.description,
      imageUrl: baseProduct.imageUrl,
      amazonPrice: latestSnapshot.amazonPrice,
      flipkartPrice: latestSnapshot.flipkartPrice,
      rating: baseProduct.rating,
      reviews: baseProduct.reviews,
      updatedAt: latestSnapshot.timestamp,
    );

    return TrackedProduct(
      id: 'tracked_$productId',
      userId: storageService.getUser()?.id ?? 'user_001',
      product: product,
      addedAt: DateTime.now(),
      targetPrice: _targetPrices[productId],
      priceHistory: history,
    );
  }

  List<PriceSnapshot> _generateInitialHistory(String productId) {
    final amazonHistory = amazonService.getPriceHistory(productId);
    final flipkartHistory = flipkartService.getPriceHistory(productId);
    final count = min(amazonHistory.length, flipkartHistory.length);

    if (count == 0) {
      return [];
    }

    final endDate = _dateOnly(DateTime.now());
    final startDate = endDate.subtract(Duration(days: count - 1));

    return List.generate(count, (index) {
      return PriceSnapshot(
        amazonPrice: amazonHistory[index],
        flipkartPrice: flipkartHistory[index],
        timestamp: startDate.add(Duration(days: index)),
      );
    });
  }

  List<PriceSnapshot> _normalizeAndRollHistory(
    String productId,
    List<PriceSnapshot> history,
  ) {
    final sorted = List<PriceSnapshot>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (sorted.isEmpty) return sorted;

    var updated = _appendMissingDailySnapshots(productId, sorted);
    updated = _trimHistory(updated);
    return updated;
  }

  List<PriceSnapshot> _appendMissingDailySnapshots(
    String productId,
    List<PriceSnapshot> history,
  ) {
    if (history.isEmpty) return history;

    var updated = List<PriceSnapshot>.from(history);
    var cursorDate = _dateOnly(updated.last.timestamp);
    final today = _dateOnly(DateTime.now());
    var dayOffset = 0;

    while (cursorDate.isBefore(today)) {
      final previous = updated.last;
      final nextDate = cursorDate.add(const Duration(days: 1));

      final nextAmazonPrice = priceHistoryGeneratorService.generateNextPrice(
        previousPrice: previous.amazonPrice,
        seedKey: '${productId}_amazon_${nextDate.millisecondsSinceEpoch}_$dayOffset',
        downwardBias: -0.0018,
      );
      final nextFlipkartPrice = priceHistoryGeneratorService.generateNextPrice(
        previousPrice: previous.flipkartPrice,
        seedKey:
            '${productId}_flipkart_${nextDate.millisecondsSinceEpoch}_$dayOffset',
        downwardBias: -0.0022,
      );

      updated.add(
        PriceSnapshot(
          amazonPrice: nextAmazonPrice,
          flipkartPrice: nextFlipkartPrice,
          timestamp: nextDate,
        ),
      );

      cursorDate = nextDate;
      dayOffset++;
    }

    return updated;
  }

  List<PriceSnapshot> _trimHistory(
    List<PriceSnapshot> history, {
    int maxPoints = 90,
  }) {
    if (history.length <= maxPoints) return history;
    return history.sublist(history.length - maxPoints);
  }

  Future<void> addTrackedProduct(Product product) async {
    try {
      await storageService.addTrackedProduct(product.id);
      await trackingApiService.addTrackedItem(product.id, targetPrice: _targetPrices[product.id]);
      final currentState = state.maybeWhen(
        data: (items) => items,
        orElse: () => <TrackedProduct>[],
      );

      var history = _generateInitialHistory(product.id);
      if (history.isEmpty) {
        history = [
          PriceSnapshot(
            amazonPrice: product.amazonPrice,
            flipkartPrice: product.flipkartPrice,
            timestamp: DateTime.now(),
          ),
        ];
      }
      history = _normalizeAndRollHistory(product.id, history);

      final latestSnapshot = history.last;
      final syncedProduct = Product(
        id: product.id,
        name: product.name,
        category: product.category,
        description: product.description,
        imageUrl: product.imageUrl,
        amazonPrice: latestSnapshot.amazonPrice,
        flipkartPrice: latestSnapshot.flipkartPrice,
        rating: product.rating,
        reviews: product.reviews,
        updatedAt: latestSnapshot.timestamp,
      );

      final trackedProduct = TrackedProduct(
        id: 'tracked_${product.id}',
        userId: storageService.getUser()?.id ?? 'user_001',
        product: syncedProduct,
        addedAt: DateTime.now(),
        targetPrice: _targetPrices[product.id],
        priceHistory: history,
      );

      _trackingData[product.id] = history;
      await storageService.savePriceHistory(product.id, history);

      final filtered = currentState.where((item) => item.product.id != product.id);
      state = AsyncValue.data([...filtered, trackedProduct]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removeTrackedProduct(String productId) async {
    try {
      await storageService.removeTrackedProduct(productId);
      await storageService.removePriceHistory(productId);
      await storageService.removeTargetPrice(productId);
      await trackingApiService.removeTrackedItem(productId);

      _trackingData.remove(productId);
      _targetPrices.remove(productId);
      _lastPriceDropAlertDay.remove(productId);
      _lastTargetAlertDay.remove(productId);

      final currentState = state.maybeWhen(
        data: (items) => items,
        orElse: () => <TrackedProduct>[],
      );

      state = AsyncValue.data(
        currentState.where((t) => t.product.id != productId).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updatePriceHistory(String productId) async {
    try {
      final currentState = state.maybeWhen(
        data: (items) => items,
        orElse: () => <TrackedProduct>[],
      );

      final existingIndex = currentState.indexWhere(
        (item) => item.product.id == productId,
      );
      if (existingIndex == -1) return;

      final existing = currentState[existingIndex];
      final currentHistory = _trackingData[productId] ?? existing.priceHistory;
      final updatedHistory = _appendNextSnapshot(productId, currentHistory);

      _trackingData[productId] = updatedHistory;
      await storageService.savePriceHistory(productId, updatedHistory);

      final latest = updatedHistory.last;
      final updatedProduct = Product(
        id: existing.product.id,
        name: existing.product.name,
        category: existing.product.category,
        description: existing.product.description,
        imageUrl: existing.product.imageUrl,
        amazonPrice: latest.amazonPrice,
        flipkartPrice: latest.flipkartPrice,
        rating: existing.product.rating,
        reviews: existing.product.reviews,
        updatedAt: latest.timestamp,
      );

      final updatedTrackedProduct = TrackedProduct(
        id: existing.id,
        userId: existing.userId,
        product: updatedProduct,
        addedAt: existing.addedAt,
        targetPrice: _targetPrices[productId] ?? existing.targetPrice,
        priceHistory: updatedHistory,
      );

      final updatedState = List<TrackedProduct>.from(currentState);
      updatedState[existingIndex] = updatedTrackedProduct;
      state = AsyncValue.data(updatedState);

      await _evaluateAlerts(updatedTrackedProduct);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  List<PriceSnapshot> _appendNextSnapshot(
    String productId,
    List<PriceSnapshot> history,
  ) {
    if (history.isEmpty) return history;

    final previous = history.last;
    final previousDate = _dateOnly(previous.timestamp);
    final today = _dateOnly(DateTime.now());
    final nextDate = previousDate.isBefore(today)
        ? previousDate.add(const Duration(days: 1))
        : DateTime.now();

    final nextAmazonPrice = priceHistoryGeneratorService.generateNextPrice(
      previousPrice: previous.amazonPrice,
      seedKey: '${productId}_amazon_manual_${nextDate.millisecondsSinceEpoch}',
      downwardBias: -0.0018,
    );
    final nextFlipkartPrice = priceHistoryGeneratorService.generateNextPrice(
      previousPrice: previous.flipkartPrice,
      seedKey: '${productId}_flipkart_manual_${nextDate.millisecondsSinceEpoch}',
      downwardBias: -0.0022,
    );

    final updated = [
      ...history,
      PriceSnapshot(
        amazonPrice: nextAmazonPrice,
        flipkartPrice: nextFlipkartPrice,
        timestamp: nextDate,
      ),
    ];
    return _trimHistory(updated);
  }

  Future<void> setTargetPrice(String productId, double targetPrice) async {
    try {
      _targetPrices[productId] = targetPrice;
      await storageService.saveTargetPrice(productId, targetPrice);
      await trackingApiService.updateTargetPrice(productId, targetPrice);

      final currentState = state.maybeWhen(
        data: (items) => items,
        orElse: () => <TrackedProduct>[],
      );

      final updatedState = currentState.map((trackedProduct) {
        if (trackedProduct.product.id != productId) return trackedProduct;

        return TrackedProduct(
          id: trackedProduct.id,
          userId: trackedProduct.userId,
          product: trackedProduct.product,
          addedAt: trackedProduct.addedAt,
          targetPrice: targetPrice,
          priceHistory: trackedProduct.priceHistory,
        );
      }).toList();

      state = AsyncValue.data(updatedState);

      final justUpdated = updatedState.where((item) => item.product.id == productId);
      if (justUpdated.isNotEmpty) {
        await _evaluateAlerts(justUpdated.first);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Removes only the price alert (target price) without untracking the product.
  Future<void> removeTargetPrice(String productId) async {
    try {
      _targetPrices.remove(productId);
      await storageService.removeTargetPrice(productId);
      await trackingApiService.updateTargetPrice(productId, null);

      final currentState = state.maybeWhen(
        data: (items) => items,
        orElse: () => <TrackedProduct>[],
      );

      final updatedState = currentState.map((trackedProduct) {
        if (trackedProduct.product.id != productId) return trackedProduct;
        return TrackedProduct(
          id: trackedProduct.id,
          userId: trackedProduct.userId,
          product: trackedProduct.product,
          addedAt: trackedProduct.addedAt,
          targetPrice: null, // alert cleared
          priceHistory: trackedProduct.priceHistory,
        );
      }).toList();

      state = AsyncValue.data(updatedState);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }


  Future<void> _evaluateAlerts(TrackedProduct trackedProduct) async {
    if (trackedProduct.priceHistory.isEmpty) return;

    final productId = trackedProduct.product.id;
    final today = _dateOnly(DateTime.now());
    final history = trackedProduct.priceHistory.map((snapshot) => snapshot.bestPrice).toList();
    final currentPrice = history.last;

    final shouldTriggerDrop = notificationService.shouldTriggerPriceDropAlert(
      currentPrice: currentPrice,
      historicalBestPrices: history,
      lookbackDays: 7,
    );

    if (shouldTriggerDrop && !_isSameDay(_lastPriceDropAlertDay[productId], today)) {
      final averagePrice = notificationService.averagePriceOfLastDays(
        history,
        lookbackDays: 7,
      );
      await notificationService.showPriceDropNotification(
        productName: trackedProduct.product.name,
        oldPrice: averagePrice.round().toString(),
        newPrice: currentPrice.round().toString(),
      );
      _lastPriceDropAlertDay[productId] = today;
    }

    final targetPrice = trackedProduct.targetPrice;
    if (targetPrice != null &&
        currentPrice <= targetPrice &&
        !_isSameDay(_lastTargetAlertDay[productId], today)) {
      await notificationService.showAlertTriggered(
        productName: trackedProduct.product.name,
        targetPrice: targetPrice.round().toString(),
        currentPrice: currentPrice.round().toString(),
      );
      _lastTargetAlertDay[productId] = today;
    }
  }

  bool _isSameDay(DateTime? left, DateTime right) {
    if (left == null) return false;
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool isProductTracked(String productId) {
    return state.maybeWhen(
      data: (items) => items.any((item) => item.product.id == productId),
      orElse: () => false,
    );
  }
}

final isProductTrackedProvider = Provider.family<bool, String>((ref, productId) {
  final tracked = ref.watch(trackedProductsProvider);
  return tracked.maybeWhen(
    data: (items) => items.any((item) => item.product.id == productId),
    orElse: () => false,
  );
});
