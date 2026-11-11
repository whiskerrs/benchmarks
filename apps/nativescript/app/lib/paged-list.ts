import { ObservableArray, type ListView } from '@nativescript/core';
import { SCREEN_HEIGHT } from './format';

export interface PageResult<T> {
  rows: T[];
  hasNextPage: boolean;
  endCursor: string | null;
}

/**
 * Infinite-scroll helper for a ListView. Rows are appended page by page. The
 * next page is requested when the user scrolls within one screen height of
 * the end (iOS: observed on the table's contentOffset; Android: when a row
 * within one screen of the end is built). A trailing loader row is shown
 * while a page is in flight.
 */
export class PagedList<T extends { kind: string }> {
  readonly items = new ObservableArray<T>();
  hasNextPage = false;
  endCursor: string | null = null;
  loading = false;
  private scheduled = false;
  private generation = 0;
  private prefetchRows: number;
  private listView: ListView | null = null;
  private observer: NSObject | null = null;

  constructor(
    rowHeight: number,
    private loader: T,
    private fetchPage: (after: string | null) => Promise<PageResult<T>>,
    private onError: (firstPage: boolean) => void,
    private onFirstPage: () => void,
  ) {
    this.prefetchRows = Math.max(1, Math.ceil(SCREEN_HEIGHT / rowHeight));
  }

  /** Empties the list and discards any in-flight page. */
  clear() {
    this.generation++;
    if (this.items.length) this.items.splice(0, this.items.length);
    this.hasNextPage = false;
    this.endCursor = null;
    this.loading = false;
  }

  /** Clears the list and loads the first page. */
  reset(): Promise<void> {
    this.clear();
    return this.load(true);
  }

  private async load(first: boolean): Promise<void> {
    const gen = this.generation;
    this.loading = true;
    if (!first) this.items.push(this.loader);
    try {
      const page = await this.fetchPage(first ? null : this.endCursor);
      if (gen !== this.generation) return;
      if (!first) this.removeLoader();
      this.hasNextPage = page.hasNextPage;
      this.endCursor = page.endCursor;
      this.loading = false;
      if (page.rows.length) this.items.push(...page.rows);
      if (first) this.onFirstPage();
      // The new content may still be shorter than one screen past the viewport.
      this.scheduleCheck();
    } catch (e) {
      if (gen !== this.generation) return;
      if (!first) this.removeLoader();
      this.loading = false;
      this.onError(first);
    }
  }

  private removeLoader() {
    const last = this.items.length - 1;
    if (last >= 0 && this.items.getItem(last) === this.loader) this.items.splice(last, 1);
  }

  private loadMore() {
    if (this.loading || !this.hasNextPage) return;
    this.load(false);
  }

  /** Runs the end-of-list check outside the current layout/cell pass. */
  private scheduleCheck() {
    if (this.scheduled) return;
    this.scheduled = true;
    const gen = this.generation;
    setTimeout(() => {
      this.scheduled = false;
      if (gen === this.generation) this.checkScroll();
    }, 0);
  }

  private checkScroll() {
    if (!__APPLE__ || !this.listView) return;
    const tv = this.listView.nativeViewProtected as UITableView;
    if (!tv) return;
    const viewport = tv.bounds.size.height;
    const remaining = tv.contentSize.height - (tv.contentOffset.y + viewport);
    if (this.items.length > 0 && remaining <= viewport) this.loadMore();
  }

  /** Call from the ListView's loaded event. */
  attach(listView: ListView) {
    this.listView = listView;
    if (__APPLE__) {
      // When a UITableViewCell leaves the window, NativeScript tears down its
      // item view and rebuilds it when the cell is reused; that rebuild
      // re-applies stale native default values and throws inside
      // cellForRowAtIndexPath (UIKit then aborts). Keeping each item view
      // attached to its cell avoids the teardown; the view is reused with the
      // cell, which is the normal recycling path.
      (listView as any)._removeContainer = () => undefined;
      (listView.nativeViewProtected as UITableView).keyboardDismissMode = UIScrollViewKeyboardDismissMode.OnDrag;
    }
    if (__APPLE__ && !this.observer) {
      const observer = createObserver(() => this.scheduleCheck());
      (listView.nativeViewProtected as UITableView).addObserverForKeyPathOptionsContext(observer, 'contentOffset', 0 as any, null);
      this.observer = observer;
    }
  }

  /** Call from the ListView's unloaded event. */
  detach() {
    if (__APPLE__ && this.observer && this.listView?.nativeViewProtected) {
      (this.listView.nativeViewProtected as UITableView).removeObserverForKeyPath(this.observer, 'contentOffset');
    }
    this.observer = null;
    this.listView = null;
  }

  /** Call from the ListView's itemLoading event (used for paging on Android). */
  onItemLoading(index: number) {
    if (__ANDROID__ && index >= this.items.length - 1 - this.prefetchRows) {
      this.scheduleAndroidLoad();
    }
  }

  private scheduleAndroidLoad() {
    if (this.scheduled) return;
    this.scheduled = true;
    const gen = this.generation;
    setTimeout(() => {
      this.scheduled = false;
      if (gen === this.generation) this.loadMore();
    }, 0);
  }
}

let ObserverClass: any;
/** NSObject subclass receiving KVO notifications (created lazily, iOS only). */
function createObserver(callback: () => void): NSObject {
  if (!ObserverClass) {
    ObserverClass = (NSObject as any).extend({
      observeValueForKeyPathOfObjectChangeContext(this: any) {
        this._callback?.();
      },
    });
  }
  const observer = ObserverClass.new();
  observer._callback = callback;
  return observer;
}

/** Template selector: loader rows use the 'loader' template, everything else 'row'. */
export function selectTemplate(item: { kind?: string } | undefined): string {
  return item?.kind === 'loader' ? 'loader' : 'row';
}

