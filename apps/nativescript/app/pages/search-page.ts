import { Observable, type EventData, type ListView, type ItemEventData, type NavigatedData, type Page, type PropertyChangeData, type View } from '@nativescript/core';
import { gql, type PageInfo, type ProductCard } from '../lib/api';
import { toCard, type CardVM } from '../lib/format';
import { openProduct, reportPage } from '../lib/nav';
import { PagedList } from '../lib/paged-list';

const ROW_HEIGHT = 101;

interface SearchRow extends Partial<CardVM> {
  kind: 'row' | 'loader';
}

interface SearchResponse {
  search: { totalCount: number; pageInfo: PageInfo; nodes: ProductCard[] };
}

class SearchVM extends Observable {
  /** The query whose results are displayed (or being loaded). */
  current = '';
  count = 0;
  list: PagedList<SearchRow>;
  private timer: any;

  constructor() {
    super();
    this.list = new PagedList<SearchRow>(
      ROW_HEIGHT,
      { kind: 'loader' },
      (after) => this.fetch(this.current, after),
      (first) => {
        if (first) this.setState('error');
      },
      () => this.setState('loaded'),
    );
    this.set('rows', this.list.items);
    this.setState('empty');
  }

  setState(state: 'empty' | 'loading' | 'loaded' | 'error') {
    this.set('emptyVisibility', state === 'empty' ? 'visible' : 'collapsed');
    this.set('skeletonVisibility', state === 'loading' ? 'visible' : 'collapsed');
    this.set('contentVisibility', state === 'loaded' ? 'visible' : 'collapsed');
    this.set('countVisibility', state === 'loaded' ? 'visible' : 'collapsed');
    this.set('errorVisibility', state === 'error' ? 'visible' : 'collapsed');
  }

  private async fetch(query: string, after: string | null) {
    const data = await gql<SearchResponse>('Search', { query, first: 24, after });
    if (query !== this.current) throw new StaleError();
    const s = data.search;
    if (!after) {
      this.count = 0;
      this.set('countText', `${s.totalCount} results`);
    }
    const start = this.count;
    this.count += s.nodes.length;
    const rows: SearchRow[] = s.nodes.map((p, i) => ({ kind: 'row', ...toCard(p, `search-result-${start + i}`, 240) }));
    return { rows, hasNextPage: s.pageInfo.hasNextPage, endCursor: s.pageInfo.endCursor };
  }

  onQueryChanged(text: string) {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.run(text), 300);
  }

  run(text: string) {
    const q = text.trim();
    this.current = q;
    if (!q) {
      this.list.clear();
      this.setState('empty');
      return;
    }
    this.setState('loading');
    this.list.reset();
  }

  retry() {
    this.run(this.current);
  }
}

class StaleError extends Error {}

export function onNavigatingTo(args: NavigatedData) {
  const page = args.object as Page;
  reportPage(page.frame, false);
  if (args.isBackNavigation) return;
  page.bindingContext = new SearchVM();
}

export function onTextChange(args: PropertyChangeData) {
  const view = args.object as unknown as View;
  const vm = view.page?.bindingContext as SearchVM;
  vm?.onQueryChanged(`${args.value ?? ''}`);
}

export function onRetry(args: { object: View }) {
  (args.object.page.bindingContext as SearchVM).retry();
}

export function onResultTap(args: ItemEventData) {
  const view = args.object as View;
  const vm = view.page.bindingContext as SearchVM;
  const row = vm.list.items.getItem(args.index);
  if (row && row.kind === 'row' && row.handle) openProduct(view, row.handle);
}

export function onItemLoading(args: ItemEventData) {
  ((args.object as View).page?.bindingContext as SearchVM)?.list.onItemLoading(args.index);
}

export function onGridLoaded(args: EventData) {
  const list = args.object as ListView;
  (list.page.bindingContext as SearchVM)?.list.attach(list);
}

export function onGridUnloaded(args: EventData) {
  ((args.object as View).page?.bindingContext as SearchVM)?.list.detach();
}

export { selectTemplate } from '../lib/paged-list';
