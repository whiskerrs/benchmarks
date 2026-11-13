import 'package:dartnative/dartnative.dart';

import '../api/models.dart';
import '../native/native_bridge.dart';
import 'icons.dart';
import 'theme.dart';

/// Gives the first native view of [child] a UIKit accessibilityIdentifier,
/// so UI automation (XCUITest) can find it.
class AxId extends StatefulWidget {
  const AxId(this.id, {super.key, required this.child});

  final String id;
  final Widget child;

  @override
  State<AxId> createState() => _AxIdState();
}

class _AxIdState extends State<AxId> {
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(AxId oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  void _apply() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is RenderBox) {
      setNativeAccessibilityIdentifier(box.viewId, widget.id);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A network image with the `width` parameter added, aspect-fill cropped,
/// showing the `surface` colour until it loads.
class NetImage extends StatelessWidget {
  const NetImage({
    super.key,
    required this.image,
    required this.width,
    this.radius = 0,
    this.w,
    this.h,
  });

  final ImageRef? image;

  /// The `width` query parameter.
  final int width;
  final double radius;
  final double? w;
  final double? h;

  @override
  Widget build(BuildContext context) {
    final img = image;
    return Container(
      width: w,
      height: h,
      clipBehavior: radius > 0 ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius > 0 ? BorderRadius.circular(radius) : null,
      ),
      child: img == null
          ? null
          : Image.network(
              sizedImageUrl(img.url, width),
              width: w ?? double.infinity,
              height: h ?? double.infinity,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
    );
  }
}

/// Price, optionally in the sale colour followed by the struck-through
/// compare-at price.
class PriceLine extends StatelessWidget {
  const PriceLine({
    super.key,
    required this.price,
    this.compareAt,
    this.fontSize = 15,
  });

  final Money price;
  final Money? compareAt;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final sale = compareAt;
    final priceText = Text(
      price.formatted,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: sale != null ? AppColors.sale : AppColors.text,
      ),
    );
    if (sale == null) return priceText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      children: [
        priceText,
        const SizedBox(width: 6),
        Text(
          sale.formatted,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            decoration: TextDecoration.lineThrough,
            decorationColor: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// The product card used by the Home best-seller grid and Collection grid:
/// 3:4 image, title (2 lines max) and price.
class ProductCardView extends StatelessWidget {
  const ProductCardView({
    super.key,
    required this.product,
    required this.onTap,
  });

  final ProductSummary product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: NetImage(image: product.image, width: 480, radius: 8),
          ),
          const SizedBox(height: 8),
          Text(
            product.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.cardTitle,
          ),
          const SizedBox(height: 8),
          PriceLine(price: product.price, compareAt: product.saleCompareAt),
        ],
      ),
    );
  }
}

/// Height of a [ProductCardView] laid out [width] wide.
double productCardHeight(double width) =>
    width * 4 / 3 + 8 + 36 + 8 + 20;

/// A horizontal carousel card, 140 wide.
class CarouselCard extends StatelessWidget {
  const CarouselCard({
    super.key,
    required this.image,
    required this.imageHeight,
    required this.title,
    this.titleStyle = AppText.cardTitle,
    this.gap = 8,
    this.price,
    required this.onTap,
  });

  final ImageRef? image;
  final double imageHeight;
  final String title;
  final TextStyle titleStyle;
  final double gap;
  final Money? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = price;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            NetImage(
              image: image,
              width: 480,
              radius: 8,
              w: 140,
              h: imageHeight,
            ),
            SizedBox(height: gap),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
            if (p != null) ...[
              SizedBox(height: gap),
              Text(
                p.formatted,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A pill chip.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.outlined = false,
    this.height = 36,
    this.fontSize = 14,
    this.padding = 14,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  /// Outlined style (sort chips): white with a border when unselected.
  final bool outlined;
  final double height;
  final double fontSize;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.text
        : (outlined ? AppColors.background : AppColors.surface);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: padding),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(height / 2),
          border: outlined
              ? Border.all(
                  color: selected ? AppColors.text : AppColors.border,
                  width: 1,
                )
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}

/// A grey loading block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.skeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Primary (filled) button: 52 tall, radius 12.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.height = 52,
    this.expand = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.text : AppColors.textMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, maxLines: 1, style: AppText.button),
      ),
    );
  }
}

/// Secondary (outlined) button: 48 tall, radius 12.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.text, width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

/// "Couldn't load products" with a Retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIconView(
              AppIcon.alert,
              size: 48,
              color: AppColors.textMuted,
              strokeWidth: 1.25,
            ),
            const SizedBox(height: 12),
            const Text(
              'Couldn’t load products',
              textAlign: TextAlign.center,
              style: AppText.sectionHeading,
            ),
            const SizedBox(height: 12),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 22 / 15,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            AxId(
              'error-retry',
              child: SecondaryButton(label: 'Retry', onTap: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 44-tall navigation bar: back button, centred title.
class NavBar extends StatelessWidget {
  const NavBar({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            AxId(
              'back',
              child: GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: AppIconView(AppIcon.back)),
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.navTitle,
              ),
            ),
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}

/// The small spinner shown at the end of a list while a page loads.
class LoadingFooter extends StatelessWidget {
  const LoadingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 56,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: AppColors.textMuted,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}
