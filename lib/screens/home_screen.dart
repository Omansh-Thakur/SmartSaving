import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tracked_products_provider.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';
import 'search_screen.dart';
import '../widgets/product_card.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/app_bar.dart';
import '../widgets/app_drawer.dart';
import '../utils/constants.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  final ScrollController _dashboardScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ref.read(trackedProductsProvider.notifier);
  }

  @override
  void dispose() {
    _dashboardScrollController.dispose();
    super.dispose();
  }

  void _scrollToTrending() {
    if (_dashboardScrollController.hasClients) {
      _dashboardScrollController.animateTo(
        _dashboardScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        scrollController: _dashboardScrollController,
        onCategoryTap: (category) {
          setState(() {
            _selectedIndex = 1;
          });
        },
      ),
      const SearchScreen(),
      _buildTrackedScreen(),
      _buildProfileScreen(),
    ];

    return Scaffold(
      drawer: AppDrawer(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) => setState(() => _selectedIndex = index),
        onScrollToTrending: _scrollToTrending,
      ),
      appBar: SmartSavingAppBar(
        title: _selectedIndex == 0
            ? AppStrings.appName
            : _selectedIndex == 1
            ? AppStrings.searchProducts
            : _selectedIndex == 2
            ? AppStrings.trackedProducts
            : AppStrings.profile,
        showLogo: false,
        showDrawerIcon: true,
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Ensure it doesn't color shift weirdly with 4 tabs
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: AppStrings.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search),
            label: "Search",
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

  Widget _buildTrackedScreen() {
    return Consumer(
      builder: (context, ref, _) {
        final trackedAsync = ref.watch(trackedProductsProvider);

        return trackedAsync.when(
          data: (tracked) {
            if (tracked.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(trackedProductsProvider);
                  await Future.delayed(const Duration(milliseconds: 1200));
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: const Color(AppColors.primary).withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 80,
                                color: const Color(AppColors.primary).withOpacity(0.2),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'Your wishlist is lonely',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Track products to see price drops and best deals across Amazon & Flipkart.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 40),
                            SizedBox(
                              width: 200,
                              child: ElevatedButton(
                                onPressed: () => setState(() => _selectedIndex = 1),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                ),
                                child: const Text('Start Exploring'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(trackedProductsProvider);
                await Future.delayed(const Duration(milliseconds: 1200));
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
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
              ),
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

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: const Color(AppColors.primary)),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet() {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    
    final nameCtrl = TextEditingController(text: user.name);
    final passCtrl = TextEditingController();
    bool isLoading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (stCtx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24, right: 24, top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name', 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password (Optional)', 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                       backgroundColor: const Color(AppColors.primary),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isLoading ? null : () async {
                      setSheetState(() { isLoading = true; error = null; });
                      try {
                        await ref.read(currentUserProvider.notifier).updateProfile(nameCtrl.text, passCtrl.text);
                        if (mounted) Navigator.of(ctx).pop();
                      } catch (e) {
                         setSheetState(() { error = e.toString().replaceAll('Exception: ', ''); isLoading = false; });
                      }
                    },
                    child: isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildProfileScreen() {
    return Consumer(
      builder: (context, ref, _) {
        final userAsync = ref.watch(currentUserProvider);

        return userAsync.when(
          data: (user) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Premium Profile Header
                  Stack(
                    children: [
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(AppColors.primary),
                              const Color(AppColors.primaryDark),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 80),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 60,
                                  color: const Color(AppColors.primary),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              user?.name ?? 'User',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              user?.email ?? 'user@example.com',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Settings Categories
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(context, 'ACCOUNT SETTINGS'),
                        _ProfileCard(
                          items: [
                            _ProfileItem(
                              icon: Icons.person_outline_rounded, 
                              title: 'Edit Profile',
                              onTap: _showEditProfileSheet,
                            ),
                            _ProfileItem(icon: Icons.notifications_none_rounded, title: 'Notifications Preferences'),
                            _ProfileItem(
                              icon: Icons.security_rounded, 
                              title: 'Security & Privacy',
                              onTap: () => _showInfoDialog('Security & Privacy', 'Your security is our top priority. We encrypt all passwords using bcrypt in our PostgreSQL databases. Please never share your credentials.'),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        _sectionTitle(context, 'SUPPORT & ABOUT'),
                        _ProfileCard(
                          items: [
                            _ProfileItem(icon: Icons.info_outline_rounded, title: 'App Version', trailing: 'v1.0.0'),
                            _ProfileItem(
                              icon: Icons.description_outlined, 
                              title: 'Terms of Service',
                              onTap: () => _showInfoDialog('Terms of Service', 'SmartSaving relies on Amazon and Flipkart public product listings. Do not abuse or spam our internal tracking systems. Usage indicates agreement.'),
                            ),
                            _ProfileItem(
                              icon: Icons.help_outline_rounded, 
                              title: 'Help Center',
                              onTap: () => _showInfoDialog('Help Center', 'Need assistance? Reach out to our 24/7 technical support team at support@smartsaving.com!'),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () {
                              ref.read(currentUserProvider.notifier).logout();
                              Navigator.of(context).pushReplacementNamed('/login');
                            },
                            icon: const Icon(Icons.logout_rounded, color: Colors.red),
                            label: const Text(
                              'Sign Out',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.red.withOpacity(0.2)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text(error.toString())),
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 2,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final List<_ProfileItem> items;
  const _ProfileCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
       shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        children: items.map((item) {
          final isLast = items.indexOf(item) == items.length - 1;
          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.primary).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, size: 20, color: const Color(AppColors.primary)),
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                trailing: item.trailing != null 
                  ? Text(item.trailing!, style: TextStyle(color: Colors.grey[400], fontSize: 12))
                  : const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: item.onTap,
              ),
              if (!isLast)
                Divider(height: 1, indent: 60, color: Theme.of(context).dividerColor.withOpacity(0.5)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ProfileItem {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  _ProfileItem({required this.icon, required this.title, this.trailing, this.onTap});
}
