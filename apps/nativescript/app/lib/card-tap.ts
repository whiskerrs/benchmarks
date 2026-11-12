import type { EventData, View } from '@nativescript/core';
import type { GridRow } from './format';
import { openProduct } from './nav';

/** Tap handler for a product card (`side="l"` or `side="r"`) inside a 2-column grid row. */
export function onCardTap(args: EventData) {
  const view = args.object as View;
  const row = view.bindingContext as GridRow;
  const handle = row?.[view.get('side') as 'l' | 'r']?.handle;
  if (handle) openProduct(view, handle);
}
