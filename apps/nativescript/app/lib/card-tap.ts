import type { EventData, View } from '@nativescript/core';
import { openProduct } from './nav';

/** Tap handler for a product card inside a 2-column grid row. */
export function onCardTap(args: EventData) {
  const view = args.object as View;
  const handle = (view.get('handle') as string) || (view.bindingContext?.[`${view.get('side')}Handle`] as string);
  if (handle) openProduct(view, handle);
}
