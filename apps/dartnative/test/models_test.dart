// Logic tests, run with `dn test`. They run on this computer.

import 'dart:io';

import 'package:everbloom/api/documents.dart';
import 'package:everbloom/api/models.dart';
import 'package:test/test.dart';

String _normalize(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// The definitions of spec/storefront.graphql, by name.
Map<String, String> _specDefinitions() {
  final src = File('spec/storefront.graphql').readAsStringSync();
  final parts = src.trim().split(RegExp(r'\n(?=fragment |query |mutation )'));
  return {
    for (final p in parts)
      RegExp(r'^(?:fragment|query|mutation) (\w+)').firstMatch(p)!.group(1)!:
          p.trim(),
  };
}

void main() {
  group('money', () {
    test('two decimals with a dollar sign', () {
      expect(formatMoney('75.0'), r'$75.00');
      expect(formatMoney('120'), r'$120.00');
      expect(formatMoney('58.5'), r'$58.50');
      expect(formatMoney('0.1'), r'$0.10');
    });
  });

  group('image url', () {
    test('adds ?width= or &width=', () {
      expect(sizedImageUrl('https://x/y.png', 480), 'https://x/y.png?width=480');
      expect(
        sizedImageUrl('https://x/y.png?v=12', 1080),
        'https://x/y.png?v=12&width=1080',
      );
    });
  });

  group('documents', () {
    final spec = _specDefinitions();
    String expected(String op, String fragment) =>
        _normalize('${spec[op]}\n${spec[fragment]}');

    test('match spec/storefront.graphql verbatim', () {
      expect(_normalize(docHome), expected('Home', 'ProductCard'));
      expect(
        _normalize(docCollectionProducts),
        expected('CollectionProducts', 'ProductCard'),
      );
      expect(_normalize(docSearch), expected('Search', 'ProductCard'));
      expect(_normalize(docProduct), expected('Product', 'ProductCard'));
      expect(_normalize(docCartCreate), expected('CartCreate', 'CartFields'));
      expect(
        _normalize(docCartLinesAdd),
        expected('CartLinesAdd', 'CartFields'),
      );
      expect(
        _normalize(docCartLinesUpdate),
        expected('CartLinesUpdate', 'CartFields'),
      );
    });
  });

  group('product', () {
    Map<String, dynamic> variant(
      String id,
      Map<String, String> opts, {
      bool available = true,
      String price = '10.0',
      String? compare,
    }) => {
      'id': id,
      'title': opts.values.join(' / '),
      'availableForSale': available,
      'selectedOptions': [
        for (final e in opts.entries) {'name': e.key, 'value': e.value},
      ],
      'price': {'amount': price, 'currencyCode': 'USD'},
      'compareAtPrice': compare == null
          ? null
          : {'amount': compare, 'currencyCode': 'USD'},
    };

    final data = {
      'product': {
        'id': 'p1',
        'handle': 'p',
        'title': 'P',
        'description': 'd',
        'images': {'nodes': <dynamic>[]},
        'options': [
          {
            'name': 'Size',
            'optionValues': [
              {'name': 'S'},
              {'name': 'M'},
            ],
          },
          {
            'name': 'Color',
            'optionValues': [
              {'name': 'Red'},
              {'name': 'Blue'},
            ],
          },
        ],
        'variants': {
          'nodes': [
            variant('v1', {'Size': 'S', 'Color': 'Red'}, available: false),
            variant('v2', {'Size': 'S', 'Color': 'Blue'}, price: '12.0'),
            variant('v3', {'Size': 'M', 'Color': 'Red'}, compare: '20.0'),
          ],
        },
      },
      'productRecommendations': <dynamic>[],
    };

    test('initial variant is the first available one', () {
      final p = ProductDetail.fromJson(data)!;
      expect(p.initialVariant!.id, 'v2');
    });

    test('selecting a pill picks the matching variant', () {
      final p = ProductDetail.fromJson(data)!;
      final v2 = p.initialVariant;
      expect(p.variantFor(v2, 'Color', 'Red')!.id, 'v1');
      expect(p.variantFor(v2, 'Size', 'M')!.id, 'v3'); // no M/Blue: first M
      final v3 = p.variantFor(v2, 'Size', 'M')!;
      expect(v3.saleCompareAt!.formatted, r'$20.00');
    });

    test('Title / Default Title option is hidden', () {
      final single = ProductDetail.fromJson({
        'product': {
          ...data['product'] as Map<String, dynamic>,
          'options': [
            {
              'name': 'Title',
              'optionValues': [
                {'name': 'Default Title'},
              ],
            },
          ],
        },
        'productRecommendations': <dynamic>[],
      })!;
      expect(single.visibleOptions, isEmpty);
    });
  });

  group('cards', () {
    test('compare-at shown only when greater than the price', () {
      ProductSummary card(String price, String compare) =>
          ProductSummary.fromJson({
            'id': '1',
            'handle': 'h',
            'title': 't',
            'featuredImage': null,
            'priceRange': {
              'minVariantPrice': {'amount': price, 'currencyCode': 'USD'},
            },
            'compareAtPriceRange': {
              'minVariantPrice': {'amount': compare, 'currencyCode': 'USD'},
            },
          });
      expect(card('45.0', '58.5').saleCompareAt, isNotNull);
      expect(card('45.0', '45.0').saleCompareAt, isNull);
      expect(card('45.0', '0.0').saleCompareAt, isNull);
    });
  });

  group('cart', () {
    test('line image falls back to the product image', () {
      final cart = Cart.fromJson({
        'id': 'c',
        'checkoutUrl': 'https://x',
        'totalQuantity': 2,
        'cost': {
          'subtotalAmount': {'amount': '20.0', 'currencyCode': 'USD'},
        },
        'lines': {
          'nodes': [
            {
              'id': 'l1',
              'quantity': 2,
              'cost': {
                'totalAmount': {'amount': '20.0', 'currencyCode': 'USD'},
              },
              'merchandise': {
                'id': 'v',
                'title': 'Default Title',
                'image': null,
                'product': {
                  'handle': 'h',
                  'title': 'Hat',
                  'featuredImage': {'url': 'https://img/p.png', 'altText': null},
                },
              },
            },
          ],
        },
      })!;
      expect(cart.lines.single.image!.url, 'https://img/p.png');
      expect(cart.subtotal.formatted, r'$20.00');
      expect(cart.totalQuantity, 2);
    });
  });
}
