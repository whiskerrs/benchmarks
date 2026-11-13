import 'package:dartnative/dartnative.dart';

import '../api/models.dart';
import '../api/storefront.dart';

enum AppTab { home, search, cart }

/// A screen pushed on a tab's stack.
sealed class PageSpec {
  const PageSpec();
}

class CollectionPageSpec extends PageSpec {
  const CollectionPageSpec(this.handle, this.title);
  final String handle;
  final String title;
}

class ProductPageSpec extends PageSpec {
  const ProductPageSpec(this.handle, this.title);
  final String handle;
  final String title;
}

class PageEntry {
  PageEntry(this.spec) : key = UniqueKey();
  final PageSpec spec;
  final Key key;
}

/// The selected tab and one stack of pushed screens per tab. Switching tabs
/// keeps every stack; the tab's root screen is not part of its stack.
class NavState extends ChangeNotifier {
  AppTab _tab = AppTab.home;
  final Map<AppTab, List<PageEntry>> _stacks = {
    for (final t in AppTab.values) t: <PageEntry>[],
  };

  AppTab get tab => _tab;
  List<PageEntry> stackOf(AppTab t) => List.unmodifiable(_stacks[t]!);

  /// The tab bar is hidden while a Product screen is on top.
  bool get tabBarVisible {
    final s = _stacks[_tab]!;
    return s.isEmpty || s.last.spec is! ProductPageSpec;
  }

  void select(AppTab t) {
    if (_tab == t) return;
    _tab = t;
    notifyListeners();
  }

  void push(PageSpec spec) {
    _stacks[_tab]!.add(PageEntry(spec));
    notifyListeners();
  }

  /// Pops the current tab's top screen. False when it is at its root.
  bool pop() {
    final s = _stacks[_tab]!;
    if (s.isEmpty) return false;
    s.removeLast();
    notifyListeners();
    return true;
  }
}

/// The in-memory cart. Every operation replaces the cart with the one in
/// the response.
class CartState extends ChangeNotifier {
  Cart? _cart;
  bool _busy = false;

  Cart? get cart => _cart;
  int get totalQuantity => _cart?.totalQuantity ?? 0;
  bool get busy => _busy;

  /// Adds one of [variantId]. Returns the first user error, if any.
  /// Throws on a network or server failure.
  Future<String?> addVariant(String variantId) {
    final cartId = _cart?.id;
    return _run(
      () => cartId == null || cartId.isEmpty
          ? Storefront.instance.cartCreate(variantId)
          : Storefront.instance.cartLinesAdd(cartId, variantId),
    );
  }

  /// Sets the quantity of line [lineId]; 0 removes it.
  Future<String?> setQuantity(String lineId, int quantity) {
    final cartId = _cart?.id;
    if (cartId == null) return Future.value(null);
    return _run(
      () => Storefront.instance.cartLinesUpdate(cartId, lineId, quantity),
    );
  }

  Future<String?> _run(Future<CartResult> Function() op) async {
    _busy = true;
    notifyListeners();
    try {
      final result = await op();
      if (result.cart != null) _cart = result.cart;
      return result.userErrors.isEmpty ? null : result.userErrors.first;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

abstract final class AppState {
  static final nav = NavState();
  static final cart = CartState();
}
