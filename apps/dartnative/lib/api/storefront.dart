import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dartnative/dartnative.dart';
import 'package:dartnative_http/http.dart';

import 'documents.dart';
import 'models.dart';

const String _defaultEndpoint = 'https://apparel-large-catalog.mock.shop/api';

/// Build-time override (Android, or any build): --dart-define=SHOP_API_URL=...
const String _buildTimeEndpoint = String.fromEnvironment('SHOP_API_URL');

/// The endpoint: the SHOP_API_URL environment variable at launch (iOS),
/// else the build-time SHOP_API_URL define, else mock.shop.
String resolveEndpoint() {
  final runtime = Platform.environment['SHOP_API_URL'];
  if (runtime != null && runtime.isNotEmpty) return runtime;
  if (_buildTimeEndpoint.isNotEmpty) return _buildTimeEndpoint;
  return _defaultEndpoint;
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => 'ApiException: $message';
}

/// Sends the operations of spec/storefront.graphql as plain HTTP POSTs.
class Storefront {
  Storefront._();
  static final Storefront instance = Storefront._();

  final Uri _endpoint = Uri.parse(resolveEndpoint());
  final NativeHttpClient _client = NativeHttpClient(
    timeout: const Duration(seconds: 20),
    cache: false,
    cookies: false,
  );

  Future<Json> _send(
    String operationName,
    String document,
    Json variables,
  ) async {
    final body = jsonEncode({
      'operationName': operationName,
      'query': document,
      'variables': variables,
    });
    final res = await _client.post(
      _endpoint,
      headers: const {'Content-Type': 'application/json'},
      body: body,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('HTTP ${res.statusCode}');
    }
    final decoded = await jsonDecodeInBackground(res.bodyBytes);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Unexpected response');
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      final errors = decoded['errors'];
      throw ApiException(errors is List && errors.isNotEmpty
          ? '${(errors.first as Map)['message']}'
          : 'No data');
    }
    return data;
  }

  Future<HomeData> home() async =>
      HomeData.fromJson(await _send('Home', docHome, const {}));

  Future<CollectionPage> collectionProducts({
    required String handle,
    required String sortKey,
    required bool reverse,
    String? after,
  }) async {
    final data = await _send('CollectionProducts', docCollectionProducts, {
      'handle': handle,
      'first': 24,
      'after': ?after,
      'sortKey': sortKey,
      'reverse': reverse,
    });
    return CollectionPage.fromJson(data);
  }

  Future<SearchPage> search(String query, {String? after}) async {
    final data = await _send('Search', docSearch, {
      'query': query,
      'first': 24,
      'after': ?after,
    });
    return SearchPage.fromJson(data);
  }

  Future<ProductDetail?> product(String handle) async {
    final data = await _send('Product', docProduct, {'handle': handle});
    return ProductDetail.fromJson(data);
  }

  Future<CartResult> cartCreate(String merchandiseId) async {
    final data = await _send('CartCreate', docCartCreate, {
      'lines': [
        {'merchandiseId': merchandiseId, 'quantity': 1},
      ],
    });
    return CartResult.fromPayload(data['cartCreate']);
  }

  Future<CartResult> cartLinesAdd(String cartId, String merchandiseId) async {
    final data = await _send('CartLinesAdd', docCartLinesAdd, {
      'cartId': cartId,
      'lines': [
        {'merchandiseId': merchandiseId, 'quantity': 1},
      ],
    });
    return CartResult.fromPayload(data['cartLinesAdd']);
  }

  Future<CartResult> cartLinesUpdate(
    String cartId,
    String lineId,
    int quantity,
  ) async {
    final data = await _send('CartLinesUpdate', docCartLinesUpdate, {
      'cartId': cartId,
      'lines': [
        {'id': lineId, 'quantity': quantity},
      ],
    });
    return CartResult.fromPayload(data['cartLinesUpdate']);
  }
}
