import type { Money, ProductCard } from './api';
import { Screen } from '@nativescript/core';

export function formatMoney(m: Money | null | undefined): string {
  if (!m) return '';
  return `$${Number(m.amount).toFixed(2)}`;
}

export function imageUrl(url: string | null | undefined, width: number): string {
  if (!url) return '';
  return `${url}${url.indexOf('?') >= 0 ? '&' : '?'}width=${width}`;
}

export const SCREEN_WIDTH = Screen.mainScreen.widthDIPs;
export const SCREEN_HEIGHT = Screen.mainScreen.heightDIPs;
/** Width of one card in the 2-column product grid (16 side padding, 12 gap). */
export const GRID_CARD_WIDTH = Math.floor((SCREEN_WIDTH - 32 - 12) / 2);
export const GRID_IMAGE_HEIGHT = Math.round((GRID_CARD_WIDTH * 4) / 3);
/** image + 8 + 2 title lines (36) + 8 + price line (20) + 20 row gap */
export const GRID_ROW_HEIGHT = GRID_IMAGE_HEIGHT + 8 + 36 + 8 + 20 + 20;

export interface CardVM {
  id: string;
  handle: string;
  title: string;
  image: string;
  imageHeight: number;
  price: string;
  priceClass: string;
  compare: string;
  compareVisibility: string;
  testID: string;
}

export function toCard(p: ProductCard, testID: string, width = 480): CardVM {
  const price = Number(p.priceRange.minVariantPrice.amount);
  const compareMoney = p.compareAtPriceRange?.minVariantPrice;
  const onSale = !!compareMoney && Number(compareMoney.amount) > price;
  return {
    id: p.id,
    handle: p.handle,
    title: p.title,
    image: imageUrl(p.featuredImage?.url, width),
    imageHeight: GRID_IMAGE_HEIGHT,
    price: formatMoney(p.priceRange.minVariantPrice),
    priceClass: onSale ? 'price sale' : 'price',
    compare: onSale ? formatMoney(compareMoney) : '',
    compareVisibility: onSale ? 'visible' : 'collapsed',
    testID,
  };
}

export interface FlatRow {
  [key: string]: unknown;
}

/** Groups cards into 2-column rows with flat l-/r-prefixed fields for XML bindings (Home). */
export function toFlatRows(cards: CardVM[]): FlatRow[] {
  const rows: FlatRow[] = [];
  for (let i = 0; i < cards.length; i += 2) {
    const row: FlatRow = {};
    const pairs: [string, CardVM | undefined][] = [
      ['l', cards[i]],
      ['r', cards[i + 1]],
    ];
    for (const [side, c] of pairs) {
      row[`${side}Handle`] = c?.handle ?? '';
      row[`${side}TestID`] = c?.testID ?? '';
      row[`${side}Image`] = c?.image ?? '';
      row[`${side}ImageHeight`] = GRID_IMAGE_HEIGHT;
      row[`${side}Title`] = c?.title ?? '';
      row[`${side}Price`] = c?.price ?? '';
      row[`${side}PriceClass`] = c?.priceClass ?? 'price';
      row[`${side}Compare`] = c?.compare ?? '';
      row[`${side}CompareVisibility`] = c?.compareVisibility ?? 'collapsed';
      row[`${side}Visibility`] = c ? 'visible' : 'hidden';
    }
    rows.push(row);
  }
  return rows;
}
