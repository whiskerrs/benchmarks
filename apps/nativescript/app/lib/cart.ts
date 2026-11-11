import { Dialogs, Observable } from '@nativescript/core';
import { gql, type Cart, type CartPayload } from './api';

/**
 * In-memory cart. Mutations are serialized so that the first add creates the
 * cart exactly once and steppers apply in order against the latest cart.
 */
class CartStore extends Observable {
  cart: Cart | null = null;
  private chain: Promise<unknown> = Promise.resolve();

  get totalQuantity(): number {
    return this.cart?.totalQuantity ?? 0;
  }

  private enqueue<T>(task: () => Promise<T>): Promise<T> {
    const run = this.chain.then(task, task);
    this.chain = run.catch(() => undefined);
    return run;
  }

  private apply(payload: CartPayload | null | undefined) {
    if (!payload) return;
    if (payload.cart) {
      this.cart = payload.cart;
      this.notify({ eventName: 'cartChanged', object: this });
    }
    if (payload.userErrors && payload.userErrors.length > 0) {
      Dialogs.alert({ title: '', message: payload.userErrors[0].message, okButtonText: 'OK' });
    }
  }

  private failed() {
    Dialogs.alert({ title: "Couldn't update cart", message: 'Check your connection and try again.', okButtonText: 'OK' });
  }

  /** Adds one of the variant. Resolves true when the request succeeded. */
  add(variantId: string): Promise<boolean> {
    return this.enqueue(async () => {
      const lines = [{ merchandiseId: variantId, quantity: 1 }];
      try {
        if (!this.cart) {
          const data = await gql<{ cartCreate: CartPayload }>('CartCreate', { lines });
          this.apply(data.cartCreate);
        } else {
          const data = await gql<{ cartLinesAdd: CartPayload }>('CartLinesAdd', { cartId: this.cart.id, lines });
          this.apply(data.cartLinesAdd);
        }
        return true;
      } catch (e) {
        this.failed();
        return false;
      }
    });
  }

  /** Changes a line's quantity by delta, relative to the latest known cart. */
  changeQuantity(lineId: string, delta: number): Promise<void> {
    return this.enqueue(async () => {
      const cart = this.cart;
      const line = cart?.lines.nodes.find((l) => l.id === lineId);
      if (!cart || !line) return;
      const quantity = Math.max(0, line.quantity + delta);
      try {
        const data = await gql<{ cartLinesUpdate: CartPayload }>('CartLinesUpdate', {
          cartId: cart.id,
          lines: [{ id: lineId, quantity }],
        });
        this.apply(data.cartLinesUpdate);
      } catch (e) {
        this.failed();
      }
    });
  }
}

export const cartStore = new CartStore();
