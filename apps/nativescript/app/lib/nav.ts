import { Frame, GridLayout, Label, View } from '@nativescript/core';
import type { Icon } from '../components/icon';
import { cartStore } from './cart';

export type TabName = 'home' | 'search' | 'cart';

const TABS: TabName[] = ['home', 'search', 'cart'];
const DEFAULT_PAGES: Record<TabName, string> = {
  home: 'pages/home-page',
  search: 'pages/search-page',
  cart: 'pages/cart-page',
};

let root: GridLayout;
let active: TabName = 'home';
const frames: Partial<Record<TabName, Frame>> = {};
/** Whether the top page of each tab's stack hides the tab bar (Product). */
const hidesTabBar: Record<string, boolean> = {};

export function attachRoot(view: GridLayout) {
  root = view;
  frames.home = view.getViewById<Frame>('frame-home');
  cartStore.on('cartChanged', updateBadge);
  updateBadge();
}

function updateBadge() {
  if (!root) return;
  const badge = root.getViewById<Label>('cart-badge');
  const qty = cartStore.totalQuantity;
  badge.text = `${qty}`;
  badge.visibility = qty > 0 ? 'visible' : 'collapsed';
}

function ensureFrame(tab: TabName): Frame {
  let frame = frames[tab];
  if (!frame) {
    frame = new Frame();
    frame.id = `frame-${tab}`;
    frames[tab] = frame;
    root.getViewById<GridLayout>('frames').addChild(frame);
    frame.navigate({ moduleName: DEFAULT_PAGES[tab], animated: false });
  }
  return frame;
}

export function selectTab(tab: TabName) {
  if (!root) return;
  ensureFrame(tab);
  active = tab;
  for (const t of TABS) {
    const f = frames[t];
    if (f) f.visibility = t === tab ? 'visible' : 'collapsed';
    const selected = t === tab;
    const icon = root.getViewById<Icon>(`tab-icon-${t}`);
    icon.iconColor = selected ? '#1C1B19' : '#6E6A63';
    const label = root.getViewById<Label>(`tab-label-${t}`);
    label.className = selected ? 'tab-label active' : 'tab-label';
  }
  refreshTabBar();
}

function refreshTabBar() {
  const bar = root?.getViewById<View>('tabbar');
  if (bar) bar.visibility = hidesTabBar[active] ? 'collapsed' : 'visible';
}

/** Called by pages when they become the top of their tab's stack. */
export function reportPage(frame: Frame | undefined, isProduct: boolean) {
  if (!frame) return;
  const tab = TABS.find((t) => frames[t] === frame);
  if (!tab) return;
  hidesTabBar[tab] = isProduct;
  if (tab === active) refreshTabBar();
}

export function openProduct(from: View, handle: string) {
  const frame = from.page.frame;
  // Hide the tab bar as the Product page is pushed (the new page is not yet
  // attached to its frame during its own navigatingTo).
  reportPage(frame, true);
  frame.navigate({ moduleName: 'pages/product-page', context: { handle } });
}

export function openCollection(from: View, handle: string, title: string) {
  from.page.frame.navigate({ moduleName: 'pages/collection-page', context: { handle, title } });
}
