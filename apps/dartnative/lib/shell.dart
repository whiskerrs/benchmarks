import 'package:dartnative/dartnative.dart';

import 'screens/cart_screen.dart';
import 'screens/collection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/product_screen.dart';
import 'screens/search_screen.dart';
import 'state/app_state.dart';
import 'ui/icons.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

/// The app's root: three tabs, each with its own stack of screens, and the
/// tab bar (hidden while a Product screen is on top).
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = AppState.nav..watch(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      brightness: Brightness.light,
      resizeToAvoidBottomInset: false,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (!AppState.nav.pop()) SystemNavigator.pop();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: IndexedStack(
                index: nav.tab.index,
                children: [
                  _TabStack(
                    root: const HomeScreen(),
                    entries: nav.stackOf(AppTab.home),
                  ),
                  _TabStack(
                    root: const SearchScreen(),
                    entries: nav.stackOf(AppTab.search),
                  ),
                  const CartScreen(),
                ],
              ),
            ),
            if (nav.tabBarVisible) const _TabBar(),
          ],
        ),
      ),
    );
  }
}

/// A tab's root screen with its pushed screens above it. Every screen stays
/// mounted, so going back finds it as it was left.
class _TabStack extends StatelessWidget {
  const _TabStack({required this.root, required this.entries});

  final Widget root;
  final List<PageEntry> entries;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: entries.length,
      children: [
        root,
        for (final e in entries)
          switch (e.spec) {
            CollectionPageSpec s => CollectionScreen(key: e.key, spec: s),
            ProductPageSpec s => ProductScreen(key: e.key, spec: s),
          },
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar();

  @override
  Widget build(BuildContext context) {
    final nav = AppState.nav..watch(context);
    final count = (AppState.cart..watch(context)).totalQuantity;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: 49,
        child: Row(
          children: [
            _TabItem(
              id: 'tab-home',
              label: 'Home',
              icon: AppIcon.home,
              selected: nav.tab == AppTab.home,
              onTap: () => AppState.nav.select(AppTab.home),
            ),
            _TabItem(
              id: 'tab-search',
              label: 'Search',
              icon: AppIcon.search,
              selected: nav.tab == AppTab.search,
              onTap: () => AppState.nav.select(AppTab.search),
            ),
            _TabItem(
              id: 'tab-cart',
              label: 'Cart',
              icon: AppIcon.cart,
              selected: nav.tab == AppTab.cart,
              badge: count > 0 ? count : null,
              onTap: () => AppState.nav.select(AppTab.cart),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String id;
  final String label;
  final AppIcon icon;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.text : AppColors.textMuted;
    final count = badge;
    return Expanded(
      child: AxId(
        id,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIconView(icon, color: color),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                if (count != null)
                  Positioned(
                    top: 4,
                    left: constraints.maxWidth / 2 + 6,
                    child: AxId('cart-badge', child: _Badge(count: count)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.sale,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );
  }
}
