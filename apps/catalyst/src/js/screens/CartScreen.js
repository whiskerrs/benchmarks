import React from "react"
import { useCart } from "../lib/cart"
import { useNav } from "../lib/nav"
import { IMG, money } from "../lib/format"
import { openInBrowser } from "../lib/native"
import { Img } from "../components/ui"
import { CartIcon, MinusIcon, PlusIcon } from "../components/Icons"

function Line({ line, index, onChange }) {
    const m = line.merchandise
    const image = m.image?.url || m.product?.featuredImage?.url
    return (
        <li className="line" role="group" aria-label={`cart-line-${index}`}>
            <Img className="line-img" url={image} width={IMG.thumb} />
            <div className="line-info">
                <span className="line-title">{m.product?.title}</span>
                {m.title && m.title !== "Default Title" ? <span className="line-variant">{m.title}</span> : null}
                <div className="line-bottom">
                    <div className="stepper">
                        <button type="button" aria-label={`qty-dec-${index}`} onClick={() => onChange(line, -1)}>
                            <MinusIcon />
                        </button>
                        <span className="qty">{line.quantity}</span>
                        <button type="button" aria-label={`qty-inc-${index}`} onClick={() => onChange(line, 1)}>
                            <PlusIcon />
                        </button>
                    </div>
                    <span className="line-total">{money(line.cost?.totalAmount)}</span>
                </div>
            </div>
        </li>
    )
}

export default function CartScreen() {
    const { cart, changeQuantity } = useCart()
    const { selectTab } = useNav()
    const lines = cart?.lines?.nodes || []

    return (
        <div className="screen with-tabs">
            <header className="cart-header">
                <h1 className="screen-title">Cart</h1>
            </header>
            {lines.length === 0 ? (
                <div className="state">
                    <CartIcon size={48} strokeWidth={1.25} />
                    <span className="state-title">Your cart is empty</span>
                    <span className="state-text">Items you add will appear here.</span>
                    <button type="button" className="btn-primary small" onClick={() => selectTab("home")}>
                        Start shopping
                    </button>
                </div>
            ) : (
                <>
                    <ul className="scroll lines">
                        {lines.map((line, i) => (
                            <Line key={line.id} line={line} index={i} onChange={changeQuantity} />
                        ))}
                    </ul>
                    <div className="summary">
                        <div className="summary-row">
                            <span>Subtotal</span>
                            <span className="subtotal" role="text" aria-label="cart-subtotal">
                                {money(cart.cost?.subtotalAmount)}
                            </span>
                        </div>
                        <span className="note">Taxes and shipping are calculated at checkout.</span>
                        <button
                            type="button"
                            className="btn-primary"
                            aria-label="checkout"
                            onClick={() => openInBrowser(cart.checkoutUrl)}
                        >
                            Check out
                        </button>
                    </div>
                </>
            )}
        </div>
    )
}
