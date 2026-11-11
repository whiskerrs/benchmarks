import { Observable, type EventData, type NavigatedData, type Page, type View } from '@nativescript/core';
import { gql, type Collection, type ProductCard } from '../lib/api';
import { imageUrl, toCard, toFlatRows } from '../lib/format';
import { logHomeReady } from '../lib/log';
import { openCollection, reportPage } from '../lib/nav';
import { setLoadState } from '../lib/state';

interface CollectionVM {
  handle: string;
  title: string;
  image: string;
  chipID: string;
  cardID: string;
}

let vm: Observable;
let firstCollection: CollectionVM | null = null;

async function load() {
  setLoadState(vm, 'loading');
  try {
    const data = await gql<{ collections: { nodes: Collection[] }; products: { nodes: ProductCard[] } }>('Home');
    const collections: CollectionVM[] = data.collections.nodes.map((c, i) => ({
      handle: c.handle,
      title: c.title,
      image: imageUrl(c.image?.url, 480),
      chipID: `collection-chip-${i}`,
      cardID: `collection-card-${i}`,
    }));
    const first = data.collections.nodes[0];
    firstCollection = collections[0] ?? null;
    vm.set('collections', collections);
    vm.set('featuredTitle', first?.title ?? '');
    vm.set('featuredImage', imageUrl(first?.image?.url, 1080));
    vm.set('bestSellers', toFlatRows(data.products.nodes.map((p, i) => toCard(p, `best-seller-${i}`))));
    setLoadState(vm, 'loaded');
    setTimeout(logHomeReady, 0);
  } catch (e) {
    setLoadState(vm, 'error');
  }
}

export function onNavigatingTo(args: NavigatedData) {
  const page = args.object as Page;
  reportPage(page.frame, false);
  if (args.isBackNavigation) return;
  vm = new Observable();
  setLoadState(vm, 'loading');
  page.bindingContext = vm;
  load();
}

export function onRetry() {
  load();
}

export function onCollectionTap(args: EventData) {
  const view = args.object as View;
  const c = view.bindingContext as CollectionVM;
  openCollection(view, c.handle, c.title);
}

export function onFeaturedTap(args: EventData) {
  if (firstCollection) openCollection(args.object as View, firstCollection.handle, firstCollection.title);
}
export { onCardTap } from '../lib/card-tap';
