import { Observable, type EventData, type NavigatedData, type Page, type ScrollEventData, type ScrollView, type View } from '@nativescript/core';
import { gql, type ProductCard, type ProductDetail, type Variant } from '../lib/api';
import { cartStore } from '../lib/cart';
import { formatMoney, imageUrl, SCREEN_WIDTH, toCard, type CardVM } from '../lib/format';
import { openProduct, reportPage, selectTab } from '../lib/nav';
import { setLoadState } from '../lib/state';

const CAROUSEL_HEIGHT = Math.round((SCREEN_WIDTH * 4) / 3);
const DOT_ON = '#1C1B19';
const DOT_OFF = 'rgba(28, 27, 25, 0.25)';

interface OptionVM {
  name: string;
  label: string;
  selected: string;
  values: { option: string; name: string; testID: string; className: string }[];
}

class ProductVM extends Observable {
  product: ProductDetail | null = null;
  variant: Variant | null = null;
  page = 0;
  adding = false;

  constructor(public handle: string) {
    super();
    this.set('carouselHeight', CAROUSEL_HEIGHT);
    this.set('addEnabled', true);
  }

  async load() {
    setLoadState(this, 'loading');
    try {
      const data = await gql<{ product: ProductDetail | null; productRecommendations: ProductCard[] | null }>('Product', {
        handle: this.handle,
      });
      const p = data.product;
      if (!p) throw new Error('Product not found');
      this.product = p;
      const images = p.images.nodes.slice(0, 10);
      this.set('title', p.title);
      this.set(
        'images',
        images.map((img) => ({ url: imageUrl(img.url, 1080), width: SCREEN_WIDTH, height: CAROUSEL_HEIGHT })),
      );
      this.page = 0;
      this.updateDots();
      this.set('description', p.description);
      this.set('descriptionVisibility', p.description ? 'visible' : 'collapsed');
      const recs: CardVM[] = (data.productRecommendations ?? []).map((r, i) => toCard(r, `recommendation-${i}`));
      this.set('recommendations', recs);
      this.set('recsVisibility', recs.length ? 'visible' : 'collapsed');
      const variants = p.variants.nodes;
      this.selectVariant(variants.find((v) => v.availableForSale) ?? variants[0] ?? null);
      setLoadState(this, 'loaded');
    } catch (e) {
      setLoadState(this, 'error');
    }
  }

  updateDots() {
    const images = (this.get('images') as unknown[]) ?? [];
    this.set(
      'dots',
      images.length > 1 ? images.map((_, i) => ({ color: i === this.page ? DOT_ON : DOT_OFF })) : [],
    );
  }

  selectVariant(v: Variant | null) {
    this.variant = v;
    const p = this.product;
    if (!p) return;
    const price = v ? formatMoney(v.price) : '';
    const onSale = !!v?.compareAtPrice && Number(v.compareAtPrice.amount) > Number(v.price.amount);
    this.set('price', price);
    this.set('priceColor', onSale ? '#B4361E' : '#1C1B19');
    this.set('compare', onSale ? formatMoney(v.compareAtPrice) : '');
    this.set('compareVisibility', onSale ? 'visible' : 'collapsed');
    this.set('addLabel', `Add to cart · ${price}`);
    const options: OptionVM[] = p.options
      .filter((o) => !(o.name === 'Title' && o.optionValues.length === 1 && o.optionValues[0].name === 'Default Title'))
      .map((o) => {
        const selected = v?.selectedOptions.find((s) => s.name === o.name)?.value ?? '';
        return {
          name: o.name,
          label: `${o.name}: `,
          selected,
          values: o.optionValues.map((val) => ({
            option: o.name,
            name: val.name,
            testID: `option-${o.name}-${val.name}`,
            className: val.name === selected ? 'pill selected' : 'pill',
          })),
        };
      });
    this.set('options', options);
  }

  pick(optionName: string, value: string) {
    const p = this.product;
    if (!p) return;
    const wanted = new Map<string, string>();
    for (const s of this.variant?.selectedOptions ?? []) wanted.set(s.name, s.value);
    wanted.set(optionName, value);
    const match =
      p.variants.nodes.find((v) => v.selectedOptions.every((s) => wanted.get(s.name) === s.value)) ??
      p.variants.nodes.find((v) => v.selectedOptions.some((s) => s.name === optionName && s.value === value));
    if (match) this.selectVariant(match);
  }
}

export function onNavigatingTo(args: NavigatedData) {
  const page = args.object as Page;
  reportPage(page.frame, true);
  if (args.isBackNavigation) return;
  const vm = new ProductVM((args.context as { handle: string }).handle);
  page.bindingContext = vm;
  vm.load();
}

export function onCarouselLoaded(args: EventData) {
  const sv = args.object as ScrollView;
  if (__APPLE__) {
    const native = sv.nativeViewProtected as UIScrollView;
    native.pagingEnabled = true;
    native.bounces = true;
  }
}

let snapTimer: any;
export function onCarouselScroll(args: ScrollEventData) {
  const sv = args.object as ScrollView;
  const vm = sv.page?.bindingContext as ProductVM;
  if (!vm) return;
  const index = Math.round(args.scrollX / SCREEN_WIDTH);
  if (index !== vm.page) {
    vm.page = index;
    vm.updateDots();
  }
  if (__ANDROID__) {
    // HorizontalScrollView has no paging; snap to the nearest page once scrolling settles.
    clearTimeout(snapTimer);
    snapTimer = setTimeout(() => {
      const target = Math.round(sv.horizontalOffset / SCREEN_WIDTH) * SCREEN_WIDTH;
      if (Math.abs(target - sv.horizontalOffset) > 1) sv.scrollToHorizontalOffset(target, true);
    }, 120);
  }
}

export function onBack(args: EventData) {
  (args.object as View).page.frame?.goBack();
}

export function onRetry(args: EventData) {
  ((args.object as View).page.bindingContext as ProductVM).load();
}

export function onPillTap(args: EventData) {
  const view = args.object as View;
  const vm = view.page.bindingContext as ProductVM;
  const item = view.bindingContext as { option: string; name: string };
  vm.pick(item.option, item.name);
}

export function onRecommendationTap(args: EventData) {
  const view = args.object as View;
  const card = view.bindingContext as CardVM;
  openProduct(view, card.handle);
}

export async function onAddToCart(args: EventData) {
  const view = args.object as View;
  const vm = view.page.bindingContext as ProductVM;
  if (!vm.variant || vm.adding) return;
  vm.adding = true;
  vm.set('addEnabled', false);
  const ok = await cartStore.add(vm.variant.id);
  vm.adding = false;
  vm.set('addEnabled', true);
  if (ok) selectTab('cart');
}
