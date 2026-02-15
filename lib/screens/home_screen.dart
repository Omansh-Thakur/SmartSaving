import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/product_provider.dart';
import '../providers/tracked_products_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/app_bar.dart';
import '../utils/constants.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(trackedProductsProvider.notifier);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildSearchScreen(),
      _buildTrackedScreen(),
      _buildProfileScreen(),
    ];

    return Scaffold(
      appBar: SmartSavingAppBar(
        title: _selectedIndex == 0
            ? AppStrings.searchProducts
            : _selectedIndex == 1
            ? AppStrings.trackedProducts
            : AppStrings.profile,
        showLogo: _selectedIndex == 0,
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.search),
            label: AppStrings.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite),
            label: AppStrings.trackedProducts,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: AppStrings.profile,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
            decoration: InputDecoration(
              hintText: AppStrings.searchProducts,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
              ),
            ),
          ),
        ),
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final productsAsync = ref.watch(productsProvider);

              return productsAsync.when(
                data: (products) {
                  if (products.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: AppDimensions.paddingM),
                          Text(
                            AppStrings.noProducts,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final isTracked = ref.watch(
                        isProductTrackedProvider(product.id),
                      );

                      return ProductCard(
                        product: product,
                        onTap: () {
                          Navigator.of(
                            context,
                          ).pushNamed('/product-detail', arguments: product);
                        },
                        onTrackTap: () async {
                          if (isTracked) {
                            await ref
                                .read(trackedProductsProvider.notifier)
                                .removeTrackedProduct(product.id);
                          } else {
                            await ref
                                .read(trackedProductsProvider.notifier)
                                .addTrackedProduct(product);
                          }
                        },
                        isTracked: isTracked,
                      );
                    },
                  );
                },
                loading: () => const ProductListSkeleton(),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: AppDimensions.paddingM),
                      Text(
                        AppStrings.error,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppDimensions.paddingM),
                      ElevatedButton(
                        onPressed: () {
                          ref.refresh(productsProvider);
                        },
                        child: const Text(AppStrings.retry),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrackedScreen() {
    return Consumer(
      builder: (context, ref, _) {
        final trackedAsync = ref.watch(trackedProductsProvider);

        return trackedAsync.when(
          data: (tracked) {
            if (tracked.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: AppDimensions.paddingM),
                    Text(
                      AppStrings.noTrackedProducts,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: tracked.length,
              itemBuilder: (context, index) {
                final trackedProduct = tracked[index];
                final product = trackedProduct.product;
                final isTracked = ref.watch(
                  isProductTrackedProvider(product.id),
                );

                return ProductCard(
                  product: product,
                  onTap: () {
                    Navigator.of(
                      context,
                    ).pushNamed('/product-detail', arguments: product);
                  },
                  onTrackTap: () async {
                    if (isTracked) {
                      await ref
                          .read(trackedProductsProvider.notifier)
                          .removeTrackedProduct(product.id);
                    }
                  },
                  isTracked: isTracked,
                );
              },
            );
          },
          loading: () => const ProductListSkeleton(),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: AppDimensions.paddingM),
                Text(
                  AppStrings.error,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileScreen() {
    return Consumer(
      builder: (context, ref, _) {
        final userAsync = ref.watch(currentUserProvider);

        return userAsync.when(
          data: (user) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.paddingL),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(AppColors.primary),
                            Color(AppColors.primaryDark),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: const Color(AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.paddingM),
                          Text(
                            user?.name ?? 'User',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: AppDimensions.paddingS),
                          Text(
                            user?.email ?? 'user@example.com',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingL),
                    ListTile(
                      leading: const Icon(Icons.info),
                      title: const Text('About'),
                      subtitle: const Text('SmartSaving v1.0.0'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip),
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {},
                    ),
                    const SizedBox(height: AppDimensions.paddingL),
                    SizedBox(
                      width: double.infinity,
                      height: AppDimensions.buttonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(currentUserProvider.notifier).logout();
                          Navigator.of(context).pushReplacementNamed('/login');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(AppColors.error),
                        ),
                        child: const Text(
                          AppStrings.logout,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text(error.toString())),
        );
      },
    );
  }
}
