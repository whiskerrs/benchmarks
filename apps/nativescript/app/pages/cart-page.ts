import { Observable, Utils, type EventData, type NavigatedData, type Page, type View } from '@nativescript/core';
import { cartStore } from '../lib/cart';
import { formatMoney, imageUrl } from '../lib/format';
import { selectTab } from '../lib/nav';

interface LineVM {
  id: string;
  title: string;
  variant: string;
  variantVisibility: string;
  image: string;
  quantity: string;
  total: string;
  testID: string;
  decID: string;
  incID: string;
}

const vm = new Observable();

function render() {
  const cart = cartStore.cart;
  const lines: LineVM[] = (cart?.lines.nodes ?? []).map((l, i) => {
    const m = l.merchandise;
    const showVariant = !!m.title && m.title !== 'Default Title';
    return {
      id: l.id,
      title: m.product.title,
      variant: showVariant ? m.title : '',
      variantVisibility: showVariant ? 'visible' : 'collapsed',
      image: imageUrl(m.image?.url ?? m.product.featuredImage?.url, 240),
      quantity: `${l.quantity}`,
      total: formatMoney(l.cost.totalAmount),
      testID: `cart-line-${i}`,
      decID: `qty-dec-${i}`,
      incID: `qty-inc-${i}`,
    };
  });
  vm.set('lines', lines);
  vm.set('subtotal', formatMoney(cart?.cost.subtotalAmount));
  vm.set('linesVisibility', lines.length ? 'visible' : 'collapsed');
  vm.set('emptyVisibility', lines.length ? 'collapsed' : 'visible');
}

cartStore.on('cartChanged', render);
render();

export function onNavigatingTo(args: NavigatedData) {
  (args.object as Page).bindingContext = vm;
}

export function onDec(args: EventData) {
  const line = (args.object as View).bindingContext as LineVM;
  cartStore.changeQuantity(line.id, -1);
}

export function onInc(args: EventData) {
  const line = (args.object as View).bindingContext as LineVM;
  cartStore.changeQuantity(line.id, 1);
}

export function onCheckout() {
  const url = cartStore.cart?.checkoutUrl;
  if (!url) return;
  if (__APPLE__) {
    SBNative.openInAppBrowser(url);
  } else {
    Utils.openUrl(url);
  }
}

export function onStartShopping() {
  selectTab('home');
}
