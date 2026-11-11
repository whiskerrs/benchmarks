import type { EventData, GridLayout } from '@nativescript/core';
import { attachRoot, selectTab } from './lib/nav';

export function onRootLoaded(args: EventData) {
  attachRoot(args.object as GridLayout);
}

export function onTabHome() {
  selectTab('home');
}

export function onTabSearch() {
  selectTab('search');
}

export function onTabCart() {
  selectTab('cart');
}
