import 'dart:async';

import 'package:dartnative/dartnative.dart';

import '../api/models.dart';
import '../api/storefront.dart';
import '../state/app_state.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _field = TextEditingController();
  final ScrollController _controller = ScrollController();
  Timer? _debounce;

  /// The query whose results are shown; responses for any other are dropped.
  String _query = '';
  int? _total;
  final List<ProductSummary> _results = [];
  String? _cursor;
  bool _hasNext = false;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onScroll);
    _controller.dispose();
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final q = text.trim();
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _results.clear();
        _total = null;
        _loading = false;
        _failed = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _start(q));
  }

  void _start(String q) {
    setState(() {
      _query = q;
      _results.clear();
      _total = null;
      _cursor = null;
      _hasNext = false;
      _failed = false;
    });
    if (_controller.hasClients) _controller.jumpTo(0);
    _fetch(reset: true);
  }

  Future<void> _fetch({required bool reset}) async {
    if (!reset && (_loading || !_hasNext)) return;
    final q = _query;
    setState(() => _loading = true);
    try {
      final page = await Storefront.instance.search(
        q,
        after: reset ? null : _cursor,
      );
      if (!mounted || q != _query) return; // stale query
      setState(() {
        _total = page.totalCount;
        _results.addAll(page.page.products);
        _cursor = page.page.endCursor;
        _hasNext = page.page.hasNextPage;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } catch (_) {
      if (!mounted || q != _query) return;
      setState(() {
        _loading = false;
        if (_total == null) _failed = true;
      });
    }
  }

  void _onScroll() {
    if (!mounted || _loading || !_hasNext || !_controller.hasClients) return;
    final pos = _controller.position;
    if (pos.maxScrollExtent - pos.pixels <= pos.viewportDimension) {
      _fetch(reset: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const AppIconView(
                    AppIcon.search,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AxId(
                      'search-input',
                      child: TextField(
                        controller: _field,
                        onChanged: _onChanged,
                        textInputAction: TextInputAction.search,
                        autocorrect: false,
                        cursorColor: AppColors.text,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.text,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search products',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_query.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(32, 48, 32, 0),
        child: Text(
          'Search across 995 products by name.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 22 / 15,
            color: AppColors.textMuted,
          ),
        ),
      );
    }
    if (_failed) return ErrorState(onRetry: () => _start(_query));
    final total = _total;
    if (total == null) {
      return const Align(
        alignment: Alignment.topCenter,
        child: LoadingFooter(),
      );
    }
    final showFooter = _loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text('$total results', style: AppText.caption),
        ),
        Expanded(
          child: AxId(
            'search-results',
            child: ListView.builder(
              controller: _controller,
              padding: const EdgeInsets.only(bottom: 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: _results.length + (showFooter ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= _results.length) return const LoadingFooter();
                final p = _results[i];
                return AxId(
                  'search-result-$i',
                  child: _ResultRow(
                    product: p,
                    onTap: () =>
                        AppState.nav.push(ProductPageSpec(p.handle, p.title)),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.product, required this.onTap});

  final ProductSummary product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: AppColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            NetImage(image: product.image, width: 240, radius: 8, w: 64, h: 85),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 20 / 15,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(product.price.formatted, style: AppText.price),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
