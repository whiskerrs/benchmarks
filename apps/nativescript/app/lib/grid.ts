import { Color, Image, Label, View, type ItemEventData } from '@nativescript/core';
import { GRID_IMAGE_HEIGHT, type CardVM } from './format';

export interface GridRow {
  kind: 'row' | 'loader';
  l?: CardVM;
  r?: CardVM;
}

export function toRows(cards: CardVM[]): GridRow[] {
  const rows: GridRow[] = [];
  for (let i = 0; i < cards.length; i += 2) rows.push({ kind: 'row', l: cards[i], r: cards[i + 1] });
  return rows;
}

/** Fills one card (ids `<side>-card`, `-img`, `-title`, `-price`, `-compare`) imperatively. */
function fillCard(root: View, side: 'l' | 'r', c: CardVM | undefined) {
  const card = root.getViewById<View>(`${side}-card`);
  if (!card) return;
  if (!c) {
    card.visibility = 'hidden';
    card.testID = '';
    return;
  }
  card.visibility = 'visible';
  card.testID = c.testID;
  card.accessibilityLabel = c.title;
  card.set('handle', c.handle);
  const img = root.getViewById<Image>(`${side}-img`);
  img.height = GRID_IMAGE_HEIGHT;
  if (img.src !== c.image) img.src = c.image;
  root.getViewById<Label>(`${side}-title`).text = c.title;
  const price = root.getViewById<Label>(`${side}-price`);
  price.text = c.price;
  price.className = c.priceClass;
  const compare = root.getViewById<Label>(`${side}-compare`);
  compare.text = c.compare;
  compare.visibility = c.compareVisibility as any;
}

/** Fills a 2-column grid row view for the given row data. */
export function fillRow(view: View, row: GridRow | undefined) {
  if (!view || !row || row.kind !== 'row') return;
  fillCard(view, 'l', row.l);
  fillCard(view, 'r', row.r);
}

export function fillGridItem(args: ItemEventData, rows: { getItem(i: number): GridRow; length: number }) {
  if (args.index < rows.length) fillRow(args.view, rows.getItem(args.index));
}

const SURFACE = '#F4F1EC';

/**
 * Placeholder color and 8pt corner radius for images inside ListView cells.
 * On iOS this is applied to the native layer directly: NativeScript's
 * background styling fails when a recycled cell's view is re-attached.
 */
export function onListImageLoaded(args: { object: View }) {
  const img = args.object as Image;
  if (__APPLE__) {
    const nv = img.nativeViewProtected as UIImageView;
    if (!nv) return;
    nv.backgroundColor = new Color(SURFACE).ios;
    nv.layer.cornerRadius = 8;
    nv.clipsToBounds = true;
  } else {
    img.backgroundColor = SURFACE;
    img.borderRadius = 8;
  }
}
