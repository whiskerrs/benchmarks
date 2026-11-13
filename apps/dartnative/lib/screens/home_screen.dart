import 'package:dartnative/dartnative.dart';

import '../api/models.dart';
import '../api/storefront.dart';
import '../native/native_bridge.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

bool _homeReadyLogged = false;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeData? _data;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    if (_failed) setState(() => _failed = false);
    try {
      final data = await Storefront.instance.home();
      if (!mounted || request != _request) return;
      setState(() => _data = data);
      if (!_homeReadyLogged) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_homeReadyLogged) return;
          _homeReadyLogged = true;
          unifiedLog('SHOPBENCH home_ready');
        });
      }
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _failed = true);
    }
  }

  void _openCollection(CollectionSummary c) =>
      AppState.nav.push(CollectionPageSpec(c.handle, c.title));

  void _openProduct(ProductSummary p) =>
      AppState.nav.push(ProductPageSpec(p.handle, p.title));

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return SafeArea(
      bottom: false,
      child: data != null
          ? _content(data)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                Expanded(
                  child: _failed ? ErrorState(onRetry: _load) : const _Skeleton(),
                ),
              ],
            ),
    );
  }

  Widget _content(HomeData data) {
    final collections = data.collections;
    final featured = collections.isNotEmpty ? collections.first : null;
    return AxId(
      'home-scroll',
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            // Collection chips.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  for (var i = 0; i < collections.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    AxId(
                      'collection-chip-$i',
                      child: Pill(
                        label: collections[i].title,
                        onTap: () => _openCollection(collections[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (featured != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: AxId(
                  'featured-collection',
                  child: _FeaturedBanner(
                    collection: featured,
                    onTap: () => _openCollection(featured),
                  ),
                ),
              ),
            // Collections carousel.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 28, 16, 12),
              child: Text('Collections', style: AppText.sectionHeading),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < collections.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    AxId(
                      'collection-card-$i',
                      child: CarouselCard(
                        image: collections[i].image,
                        imageHeight: 175,
                        title: collections[i].title,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          height: 18 / 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                        onTap: () => _openCollection(collections[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Best sellers grid.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 28, 16, 12),
              child: Text('Best sellers', style: AppText.sectionHeading),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _BestSellerGrid(
                products: data.bestSellers,
                onTap: _openProduct,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 44,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Everbloom', style: AppText.wordmark),
        ),
      ),
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({required this.collection, required this.onTap});

  final CollectionSummary collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 240,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: NetImage(image: collection.image, width: 1080),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: AppColors.bannerScrim,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'FEATURED COLLECTION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      collection.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Shop now',
                      style: TextStyle(fontSize: 14, color: AppColors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestSellerGrid extends StatelessWidget {
  const _BestSellerGrid({required this.products, required this.onTap});

  final List<ProductSummary> products;
  final void Function(ProductSummary) onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < products.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 20));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _cell(i)),
            const SizedBox(width: 12),
            Expanded(
              child: i + 1 < products.length
                  ? _cell(i + 1)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _cell(int i) => AxId(
    'best-seller-$i',
    child: ProductCardView(
      product: products[i],
      onTap: () => onTap(products[i]),
    ),
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              SkeletonBox(width: 52, height: 36, radius: 18),
              SizedBox(width: 8),
              SkeletonBox(width: 110, height: 36, radius: 18),
              SizedBox(width: 8),
              SkeletonBox(width: 96, height: 36, radius: 18),
              SizedBox(width: 8),
              SkeletonBox(width: 80, height: 36, radius: 18),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SkeletonBox(height: 240, radius: 12),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 28, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBox(width: 120, height: 18, radius: 4),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SkeletonBox(width: 140, height: 175),
              SizedBox(width: 12),
              SkeletonBox(width: 140, height: 175),
              SizedBox(width: 12),
              SkeletonBox(width: 140, height: 175),
            ],
          ),
        ),
      ],
    );
  }
}
