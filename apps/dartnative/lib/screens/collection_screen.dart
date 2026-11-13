import 'package:dartnative/dartnative.dart';

import '../api/models.dart';
import '../api/storefront.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class _Sort {
  const _Sort(this.id, this.label, this.sortKey, this.reverse);
  final String id;
  final String label;
  final String sortKey;
  final bool reverse;
}

const _sorts = [
  _Sort('sort-featured', 'Featured', 'COLLECTION_DEFAULT', false),
  _Sort('sort-best-selling', 'Best selling', 'BEST_SELLING', false),
  _Sort('sort-price-asc', 'Price: low to high', 'PRICE', false),
  _Sort('sort-price-desc', 'Price: high to low', 'PRICE', true),
];

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, required this.spec});

  final CollectionPageSpec spec;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  int _sortIndex = 0;

  String? _title;
  String _description = '';
  final List<ProductSummary> _products = [];
  String? _cursor;
  bool _hasNext = false;
  bool _loading = false;
  bool _failed = false;
  bool _loadedOnce = false;

  /// Bumped on every reload so responses for an older sort are dropped.
  int _generation = 0;
  ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _loadPage(reset: true);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _selectSort(int index) {
    if (index == _sortIndex) return;
    setState(() => _sortIndex = index);
    _loadPage(reset: true);
  }

  Future<void> _loadPage({required bool reset}) async {
    if (reset) {
      _generation++;
      // A fresh controller for the fresh grid; the old one is let go once
      // the old grid has left the tree.
      final old = _controller..removeListener(_onScroll);
      _controller = ScrollController()..addListener(_onScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      setState(() {
        _products.clear();
        _cursor = null;
        _hasNext = false;
        _failed = false;
        _loadedOnce = false;
        _loading = true;
      });
    } else {
      if (_loading || !_hasNext) return;
      setState(() => _loading = true);
    }
    final generation = _generation;
    final sort = _sorts[_sortIndex];
    try {
      final page = await Storefront.instance.collectionProducts(
        handle: widget.spec.handle,
        sortKey: sort.sortKey,
        reverse: sort.reverse,
        after: reset ? null : _cursor,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (page.title.isNotEmpty) _title = page.title;
        _description = page.description;
        _products.addAll(page.page.products);
        _cursor = page.page.endCursor;
        _hasNext = page.page.hasNextPage;
        _loading = false;
        _loadedOnce = true;
      });
      // A short page may not fill the screen: check again once laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        // A failed first page shows the error state; a failed later page
        // is retried the next time the user scrolls near the end.
        if (!_loadedOnce) _failed = true;
      });
    }
  }

  void _onScroll() {
    if (!mounted || _loading || !_hasNext || !_controller.hasClients) return;
    final pos = _controller.position;
    if (pos.maxScrollExtent - pos.pixels <= pos.viewportDimension) {
      _loadPage(reset: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavBar(
            title: _title ?? widget.spec.title,
            onBack: () => AppState.nav.pop(),
          ),
          if (_description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                _description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                for (var i = 0; i < _sorts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  AxId(
                    _sorts[i].id,
                    child: Pill(
                      label: _sorts[i].label,
                      selected: i == _sortIndex,
                      outlined: true,
                      height: 32,
                      fontSize: 13,
                      padding: 12,
                      onTap: () => _selectSort(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_failed) return ErrorState(onRetry: () => _loadPage(reset: true));
    if (!_loadedOnce) {
      return const Align(
        alignment: Alignment.topCenter,
        child: LoadingFooter(),
      );
    }
    final width = MediaQuery.of(context).size.width;
    final cellWidth = (width - 32 - 12) / 2;
    return AxId(
      'product-grid',
      key: ValueKey(_generation),
      child: CustomScrollView(
        controller: _controller,
        padding: EdgeInsets.zero,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 12,
                mainAxisExtent: productCardHeight(cellWidth),
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => AxId(
                  'product-card-$i',
                  child: ProductCardView(
                    product: _products[i],
                    onTap: () => AppState.nav.push(
                      ProductPageSpec(_products[i].handle, _products[i].title),
                    ),
                  ),
                ),
                childCount: _products.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _loading
                ? const LoadingFooter()
                : const SizedBox(height: 24),
          ),
        ],
      ),
    );
  }
}
