import 'package:dartnative/dartnative.dart';

import '../api/models.dart';
import '../api/storefront.dart';
import '../state/app_state.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.spec});

  final ProductPageSpec spec;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  ProductDetail? _product;
  Variant? _variant;
  bool _failed = false;
  bool _adding = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final p = await Storefront.instance.product(widget.spec.handle);
      if (!mounted) return;
      if (p == null) {
        setState(() => _failed = true);
        return;
      }
      setState(() {
        _product = p;
        _variant = p.initialVariant;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _addToCart() async {
    final variant = _variant;
    if (variant == null || _adding) return;
    setState(() => _adding = true);
    String? error;
    var failed = false;
    try {
      error = await AppState.cart.addVariant(variant.id);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => _adding = false);
    if (failed) {
      await showAlert(
        context: context,
        title: 'Couldn’t add to cart',
        message: 'Check your connection and try again.',
      );
      return;
    }
    if (error != null) {
      await showAlert(context: context, title: error);
      return;
    }
    AppState.nav.select(AppTab.cart);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final product = _product;
    return Stack(
      children: [
        Positioned.fill(
          child: product != null
              ? _content(product)
              : _failed
              ? Padding(
                  padding: EdgeInsets.only(top: top + 44),
                  child: ErrorState(onRetry: _load),
                )
              : const _Skeleton(),
        ),
        if (product != null)
          Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar(context)),
        Positioned(
          top: top,
          left: 12,
          child: AxId(
            'back',
            child: GestureDetector(
              onTap: () => AppState.nav.pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: const AppIconView(AppIcon.back, size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(ProductDetail product) {
    final variant = _variant;
    final price = variant?.price;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: 76 + MediaQuery.paddingOf(context).bottom + 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _carousel(product),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 28 / 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                if (price != null)
                  PriceLine(
                    price: price,
                    compareAt: variant?.saleCompareAt,
                    fontSize: 20,
                  ),
              ],
            ),
          ),
          for (final option in product.visibleOptions) _optionRow(product, option),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 22 / 15,
                    color: AppColors.body,
                  ),
                ),
              ],
            ),
          ),
          if (product.recommendations.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 32, 16, 12),
              child: Text('You may also like', style: AppText.sectionHeading),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < product.recommendations.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    AxId(
                      'recommendation-$i',
                      child: CarouselCard(
                        image: product.recommendations[i].image,
                        imageHeight: 187,
                        title: product.recommendations[i].title,
                        gap: 6,
                        price: product.recommendations[i].price,
                        onTap: () => AppState.nav.push(
                          ProductPageSpec(
                            product.recommendations[i].handle,
                            product.recommendations[i].title,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _carousel(ProductDetail product) {
    final images = product.images;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        color: AppColors.surface,
        child: images.isEmpty
            ? null
            : Stack(
                children: [
                  Positioned.fill(
                    child: AxId(
                      'product-carousel',
                      child: PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (context, i) =>
                            NetImage(image: images[i], width: 1080),
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: IgnorePointer(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < images.length; i++)
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i == _page
                                          ? AppColors.text
                                          : AppColors.dotInactive,
                                    ),
                                  ),
                                ),
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

  Widget _optionRow(ProductDetail product, ProductOption option) {
    final selected = _variant?.selectedOptions[option.name] ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              children: [
                TextSpan(text: '${option.name}: '),
                TextSpan(
                  text: selected,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in option.values)
                AxId(
                  'option-${option.name}-$value',
                  child: _OptionPill(
                    label: value,
                    selected: value == selected,
                    onTap: () => setState(() {
                      _variant = product.variantFor(
                        _variant,
                        option.name,
                        value,
                      );
                    }),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final price = _variant?.price.formatted ?? '';
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: AxId(
        'add-to-cart',
        child: PrimaryButton(
          label: 'Add to cart · $price',
          enabled: !_adding && _variant != null,
          onTap: _addToCart,
        ),
      ),
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        constraints: const BoxConstraints(minWidth: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.text : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(aspectRatio: 3 / 4, child: SkeletonBox(radius: 0)),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 240, height: 24, radius: 4),
              SizedBox(height: 10),
              SkeletonBox(width: 90, height: 22, radius: 4),
            ],
          ),
        ),
      ],
    );
  }
}
