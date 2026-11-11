import { Observable, type ListView, type EventData, type ItemEventData, type NavigatedData, type Page, type View } from '@nativescript/core';
import { gql, type PageInfo, type ProductCard } from '../lib/api';
import { GRID_ROW_HEIGHT, toCard } from '../lib/format';
import { fillGridItem, toRows, type GridRow } from '../lib/grid';
import { reportPage } from '../lib/nav';
import { PagedList, selectTemplate } from '../lib/paged-list';
import { setLoadState } from '../lib/state';

const SORTS = {
  featured: { sortKey: 'COLLECTION_DEFAULT', reverse: false, prop: 'sortFeaturedClass' },
  best: { sortKey: 'BEST_SELLING', reverse: false, prop: 'sortBestClass' },
  asc: { sortKey: 'PRICE', reverse: false, prop: 'sortAscClass' },
  desc: { sortKey: 'PRICE', reverse: true, prop: 'sortDescClass' },
};
type SortId = keyof typeof SORTS;

interface CollectionResponse {
  collection: {
    id: string;
    title: string;
    description: string;
    products: { pageInfo: PageInfo; nodes: ProductCard[] };
  } | null;
}

class CollectionVM extends Observable {
  sort: SortId = 'featured';
  count = 0;
  list: PagedList<GridRow>;

  constructor(public handle: string, title: string) {
    super();
    this.set('title', title);
    this.set('rowHeight', GRID_ROW_HEIGHT);
    this.set('descriptionVisibility', 'collapsed');
    this.list = new PagedList<GridRow>(
      GRID_ROW_HEIGHT,
      { kind: 'loader' },
      (after) => this.fetch(after),
      (first) => {
        if (first) setLoadState(this, 'error');
      },
      () => setLoadState(this, 'loaded'),
    );
    this.set('rows', this.list.items);
    this.applySortClasses();
  }

  private async fetch(after: string | null) {
    const { sortKey, reverse } = SORTS[this.sort];
    const data = await gql<CollectionResponse>('CollectionProducts', {
      handle: this.handle,
      first: 24,
      after,
      sortKey,
      reverse,
    });
    const c = data.collection;
    if (!c) throw new Error('Collection not found');
    this.set('title', c.title);
    this.set('description', c.description);
    this.set('descriptionVisibility', c.description ? 'visible' : 'collapsed');
    if (!after) this.count = 0;
    const start = this.count;
    this.count += c.products.nodes.length;
    const cards = c.products.nodes.map((p, i) => toCard(p, `product-card-${start + i}`));
    return { rows: toRows(cards), hasNextPage: c.products.pageInfo.hasNextPage, endCursor: c.products.pageInfo.endCursor };
  }

  applySortClasses() {
    for (const id of Object.keys(SORTS) as SortId[]) {
      this.set(SORTS[id].prop, id === this.sort ? 'sort-chip selected' : 'sort-chip');
    }
  }

  reload() {
    setLoadState(this, 'loading');
    this.list.reset();
  }
}

export function onNavigatingTo(args: NavigatedData) {
  const page = args.object as Page;
  reportPage(page.frame, false);
  if (args.isBackNavigation) return;
  const ctx = args.context as { handle: string; title: string };
  const vm = new CollectionVM(ctx.handle, ctx.title);
  page.bindingContext = vm;
  vm.reload();
}

export function onBack(args: EventData) {
  (args.object as View).page.frame?.goBack();
}

export function onRetry(args: EventData) {
  ((args.object as View).page.bindingContext as CollectionVM).reload();
}

export function onSort(args: EventData) {
  const view = args.object as View;
  const vm = view.page.bindingContext as CollectionVM;
  const id = view.get('sortKey') as SortId;
  if (vm.sort === id) return;
  vm.sort = id;
  vm.applySortClasses();
  vm.reload();
}

export function onItemLoading(args: ItemEventData) {
  const vm = (args.object as View).page?.bindingContext as CollectionVM;
  if (!vm) return;
  fillGridItem(args, vm.list.items);
  vm.list.onItemLoading(args.index);
}
export { onCardTap } from '../lib/card-tap';

export function onGridLoaded(args: EventData) {
  const list = args.object as ListView;
  list.itemTemplateSelector = selectTemplate;
  list.rowHeight = GRID_ROW_HEIGHT;
  (list.page.bindingContext as CollectionVM)?.list.attach(list);
}

export function onGridUnloaded(args: EventData) {
  ((args.object as View).page?.bindingContext as CollectionVM)?.list.detach();
}
export { onListImageLoaded } from '../lib/grid';
