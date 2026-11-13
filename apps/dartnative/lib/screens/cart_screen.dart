import 'package:dartnative/dartnative.dart';
import 'package:dartnative_url_launcher/dartnative_url_launcher.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _setQuantity(
    BuildContext context,
    CartLine line,
    int quantity,
  ) async {
    final cart = AppState.cart;
    if (cart.busy) return;
    String? error;
    var failed = false;
    try {
      error = await cart.setQuantity(line.id, quantity);
    } catch (_) {
      failed = true;
    }
    if (!context.mounted) return;
    if (failed) {
      await showAlert(
        context: context,
        title: 'Couldn’t update cart',
        message: 'Check your connection and try again.',
      );
    } else if (error != null) {
      await showAlert(context: context, title: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = AppState.cart..watch(context);
    final cart = cartState.cart;
    final lines = cart?.lines ?? const <CartLine>[];
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            height: 44,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Cart', style: AppText.screenTitle),
              ),
            ),
          ),
          if (cart == null || lines.isEmpty)
            const Expanded(child: _EmptyCart())
          else ...[
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: lines.length,
                itemBuilder: (context, i) => AxId(
                  'cart-line-$i',
                  child: _LineRow(
                    index: i,
                    line: lines[i],
                    onChange: (q) => _setQuantity(context, lines[i], q),
                  ),
                ),
              ),
            ),
            _Summary(cart: cart),
          ],
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.index,
    required this.line,
    required this.onChange,
  });

  final int index;
  final CartLine line;
  final void Function(int quantity) onChange;

  @override
  Widget build(BuildContext context) {
    final showVariant =
        line.variantTitle.isNotEmpty && line.variantTitle != 'Default Title';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetImage(image: line.image, width: 240, radius: 8, w: 80, h: 107),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 107,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    line.productTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 20 / 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  if (showVariant) ...[
                    const SizedBox(height: 4),
                    Text(
                      line.variantTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      _Stepper(
                        index: index,
                        quantity: line.quantity,
                        onChange: onChange,
                      ),
                      const Spacer(),
                      Text(line.total.formatted, style: AppText.price),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.index,
    required this.quantity,
    required this.onChange,
  });

  final int index;
  final int quantity;
  final void Function(int quantity) onChange;

  Widget _button(String id, AppIcon icon, VoidCallback onTap) => AxId(
    id,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 36,
        height: 34,
        child: Center(
          child: AppIconView(icon, size: 16, strokeWidth: 2),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button('qty-dec-$index', AppIcon.minus, () => onChange(quantity - 1)),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 24),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
          _button('qty-inc-$index', AppIcon.plus, () => onChange(quantity + 1)),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Subtotal',
                style: TextStyle(fontSize: 15, color: AppColors.text),
              ),
              const Spacer(),
              AxId(
                'cart-subtotal',
                child: Text(
                  cart.subtotal.formatted,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Taxes and shipping are calculated at checkout.',
            style: AppText.caption,
          ),
          const SizedBox(height: 12),
          AxId(
            'checkout',
            child: PrimaryButton(
              label: 'Check out',
              onTap: () {
                if (cart.checkoutUrl.isNotEmpty) {
                  DartNativeUrlLauncher.launch(cart.checkoutUrl);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIconView(
              AppIcon.cart,
              size: 48,
              color: AppColors.textMuted,
              strokeWidth: 1.25,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your cart is empty',
              textAlign: TextAlign.center,
              style: AppText.sectionHeading,
            ),
            const SizedBox(height: 12),
            const Text(
              'Items you add will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 22 / 15,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Start shopping',
              height: 48,
              expand: false,
              onTap: () => AppState.nav.select(AppTab.home),
            ),
          ],
        ),
      ),
    );
  }
}
