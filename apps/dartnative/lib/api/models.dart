// Plain data classes parsed from Storefront API responses.

typedef Json = Map<String, dynamic>;

Json? _map(Object? v) => v is Map<String, dynamic> ? v : null;
List<dynamic> _list(Object? v) => v is List ? v : const [];
String _str(Object? v) => v is String ? v : '';

class Money {
  const Money(this.amount, this.currencyCode);

  /// The amount as sent by the API, for example "75.0".
  final String amount;
  final String currencyCode;

  double get value => double.tryParse(amount) ?? 0;

  /// "$" followed by the amount with two decimals: "75.0" -> "$75.00".
  String get formatted => formatMoney(amount);

  static Money? fromJson(Object? json) {
    final m = _map(json);
    if (m == null) return null;
    return Money(_str(m['amount']), _str(m['currencyCode']));
  }
}

String formatMoney(String amount) {
  final v = double.tryParse(amount) ?? 0;
  return '\$${v.toStringAsFixed(2)}';
}

class ImageRef {
  const ImageRef(this.url, this.altText);
  final String url;
  final String? altText;

  static ImageRef? fromJson(Object? json) {
    final m = _map(json);
    if (m == null) return null;
    final url = _str(m['url']);
    if (url.isEmpty) return null;
    return ImageRef(url, m['altText'] as String?);
  }
}

/// Adds the `width` query parameter the spec asks for before loading an
/// image: `?width=N` without a query string, `&width=N` with one.
String sizedImageUrl(String url, int width) {
  final sep = url.contains('?') ? '&' : '?';
  return '$url${sep}width=$width';
}

class CollectionSummary {
  const CollectionSummary({
    required this.id,
    required this.handle,
    required this.title,
    this.image,
  });

  final String id;
  final String handle;
  final String title;
  final ImageRef? image;

  static CollectionSummary fromJson(Json m) => CollectionSummary(
    id: _str(m['id']),
    handle: _str(m['handle']),
    title: _str(m['title']),
    image: ImageRef.fromJson(m['image']),
  );
}

class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.handle,
    required this.title,
    this.image,
    required this.price,
    this.compareAt,
  });

  final String id;
  final String handle;
  final String title;
  final ImageRef? image;
  final Money price;
  final Money? compareAt;

  /// The compare-at price, only when it is greater than the price.
  Money? get saleCompareAt =>
      compareAt != null && compareAt!.value > price.value ? compareAt : null;

  static ProductSummary fromJson(Json m) => ProductSummary(
    id: _str(m['id']),
    handle: _str(m['handle']),
    title: _str(m['title']),
    image: ImageRef.fromJson(m['featuredImage']),
    price:
        Money.fromJson(_map(m['priceRange'])?['minVariantPrice']) ??
        const Money('0', 'USD'),
    compareAt: Money.fromJson(
      _map(m['compareAtPriceRange'])?['minVariantPrice'],
    ),
  );
}

class HomeData {
  const HomeData(this.collections, this.bestSellers);
  final List<CollectionSummary> collections;
  final List<ProductSummary> bestSellers;

  static HomeData fromJson(Json data) => HomeData(
    _list(_map(data['collections'])?['nodes'])
        .whereType<Json>()
        .map(CollectionSummary.fromJson)
        .toList(),
    _list(_map(data['products'])?['nodes'])
        .whereType<Json>()
        .map(ProductSummary.fromJson)
        .toList(),
  );
}

class ProductPage {
  const ProductPage(this.products, this.hasNextPage, this.endCursor);
  final List<ProductSummary> products;
  final bool hasNextPage;
  final String? endCursor;

  static ProductPage fromConnection(Json? conn) {
    final pageInfo = _map(conn?['pageInfo']);
    return ProductPage(
      _list(conn?['nodes'])
          .whereType<Json>()
          // Search can return non-product nodes as empty objects.
          .where((n) => n['id'] != null)
          .map(ProductSummary.fromJson)
          .toList(),
      pageInfo?['hasNextPage'] == true,
      pageInfo?['endCursor'] as String?,
    );
  }
}

class CollectionPage {
  const CollectionPage(this.title, this.description, this.page);
  final String title;
  final String description;
  final ProductPage page;

  static CollectionPage fromJson(Json data) {
    final c = _map(data['collection']);
    return CollectionPage(
      _str(c?['title']),
      _str(c?['description']),
      ProductPage.fromConnection(_map(c?['products'])),
    );
  }
}

class SearchPage {
  const SearchPage(this.totalCount, this.page);
  final int totalCount;
  final ProductPage page;

  static SearchPage fromJson(Json data) {
    final s = _map(data['search']);
    return SearchPage(
      (s?['totalCount'] as num?)?.toInt() ?? 0,
      ProductPage.fromConnection(s),
    );
  }
}

class ProductOption {
  const ProductOption(this.name, this.values);
  final String name;
  final List<String> values;
}

class Variant {
  const Variant({
    required this.id,
    required this.title,
    required this.availableForSale,
    required this.selectedOptions,
    required this.price,
    this.compareAtPrice,
  });

  final String id;
  final String title;
  final bool availableForSale;
  final Map<String, String> selectedOptions;
  final Money price;
  final Money? compareAtPrice;

  Money? get saleCompareAt =>
      compareAtPrice != null && compareAtPrice!.value > price.value
      ? compareAtPrice
      : null;

  static Variant fromJson(Json m) => Variant(
    id: _str(m['id']),
    title: _str(m['title']),
    availableForSale: m['availableForSale'] == true,
    selectedOptions: {
      for (final o in _list(m['selectedOptions']).whereType<Json>())
        _str(o['name']): _str(o['value']),
    },
    price: Money.fromJson(m['price']) ?? const Money('0', 'USD'),
    compareAtPrice: Money.fromJson(m['compareAtPrice']),
  );
}

class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.handle,
    required this.title,
    required this.description,
    required this.images,
    required this.options,
    required this.variants,
    required this.recommendations,
  });

  final String id;
  final String handle;
  final String title;
  final String description;
  final List<ImageRef> images;
  final List<ProductOption> options;
  final List<Variant> variants;
  final List<ProductSummary> recommendations;

  /// Options shown as pill rows: everything except the placeholder option
  /// `Title` with the single value `Default Title`.
  List<ProductOption> get visibleOptions => options
      .where(
        (o) =>
            !(o.name == 'Title' &&
                o.values.length == 1 &&
                o.values.first == 'Default Title'),
      )
      .toList();

  /// The first variant for sale, else the first variant.
  Variant? get initialVariant {
    if (variants.isEmpty) return null;
    return variants.firstWhere(
      (v) => v.availableForSale,
      orElse: () => variants.first,
    );
  }

  /// The variant to select when the pill [value] of option [name] is tapped
  /// while [current] is selected: the variant whose selectedOptions match the
  /// current selection with that one option changed. If no variant has that
  /// exact combination, the first variant with the tapped value.
  Variant? variantFor(Variant? current, String name, String value) {
    final wanted = <String, String>{...?current?.selectedOptions, name: value};
    for (final v in variants) {
      var match = true;
      for (final e in wanted.entries) {
        if (v.selectedOptions[e.key] != e.value) {
          match = false;
          break;
        }
      }
      if (match) return v;
    }
    for (final v in variants) {
      if (v.selectedOptions[name] == value) return v;
    }
    return current;
  }

  static ProductDetail? fromJson(Json data) {
    final p = _map(data['product']);
    if (p == null) return null;
    return ProductDetail(
      id: _str(p['id']),
      handle: _str(p['handle']),
      title: _str(p['title']),
      description: _str(p['description']),
      images: _list(_map(p['images'])?['nodes'])
          .map(ImageRef.fromJson)
          .whereType<ImageRef>()
          .toList(),
      options: _list(p['options'])
          .whereType<Json>()
          .map(
            (o) => ProductOption(
              _str(o['name']),
              _list(
                o['optionValues'],
              ).whereType<Json>().map((v) => _str(v['name'])).toList(),
            ),
          )
          .toList(),
      variants: _list(
        _map(p['variants'])?['nodes'],
      ).whereType<Json>().map(Variant.fromJson).toList(),
      recommendations: _list(
        data['productRecommendations'],
      ).whereType<Json>().map(ProductSummary.fromJson).toList(),
    );
  }
}

class CartLine {
  const CartLine({
    required this.id,
    required this.quantity,
    required this.total,
    required this.variantTitle,
    required this.productTitle,
    this.image,
  });

  final String id;
  final int quantity;
  final Money total;
  final String variantTitle;
  final String productTitle;

  /// Variant image, falling back to the product's featured image.
  final ImageRef? image;

  static CartLine fromJson(Json m) {
    final merch = _map(m['merchandise']);
    final product = _map(merch?['product']);
    return CartLine(
      id: _str(m['id']),
      quantity: (m['quantity'] as num?)?.toInt() ?? 0,
      total:
          Money.fromJson(_map(m['cost'])?['totalAmount']) ??
          const Money('0', 'USD'),
      variantTitle: _str(merch?['title']),
      productTitle: _str(product?['title']),
      image:
          ImageRef.fromJson(merch?['image']) ??
          ImageRef.fromJson(product?['featuredImage']),
    );
  }
}

class Cart {
  const Cart({
    required this.id,
    required this.checkoutUrl,
    required this.totalQuantity,
    required this.subtotal,
    required this.lines,
  });

  final String id;
  final String checkoutUrl;
  final int totalQuantity;
  final Money subtotal;
  final List<CartLine> lines;

  static Cart? fromJson(Object? json) {
    final m = _map(json);
    if (m == null) return null;
    return Cart(
      id: _str(m['id']),
      checkoutUrl: _str(m['checkoutUrl']),
      totalQuantity: (m['totalQuantity'] as num?)?.toInt() ?? 0,
      subtotal:
          Money.fromJson(_map(m['cost'])?['subtotalAmount']) ??
          const Money('0', 'USD'),
      lines: _list(
        _map(m['lines'])?['nodes'],
      ).whereType<Json>().map(CartLine.fromJson).toList(),
    );
  }
}

/// The `cart` and `userErrors` of a cart mutation payload.
class CartResult {
  const CartResult(this.cart, this.userErrors);
  final Cart? cart;
  final List<String> userErrors;

  static CartResult fromPayload(Object? payload) {
    final p = _map(payload);
    return CartResult(
      Cart.fromJson(p?['cart']),
      _list(
        p?['userErrors'],
      ).whereType<Json>().map((e) => _str(e['message'])).toList(),
    );
  }
}
