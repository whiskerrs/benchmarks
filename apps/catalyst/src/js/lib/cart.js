// In-memory cart (never persisted). Every cart operation replaces the displayed
// cart with the `cart` from its response. Operations run one at a time, in order.
import { createContext, useCallback, useContext, useMemo, useRef, useState } from "react"
import { gql } from "../api/graphql"
import { showAlert } from "./native"

const NETWORK_MESSAGE = "Couldn't update the cart. Check your connection and try again."

export const CartContext = createContext(null)
export const useCart = () => useContext(CartContext)

export function useCartStore(selectTab) {
    const [cart, setCart] = useState(null)
    const [adding, setAdding] = useState(false)
    const cartId = useRef(null)
    const queue = useRef(Promise.resolve())
    // Quantity last requested per line, so quick repeated taps build on each other.
    const requested = useRef({})

    const enqueue = useCallback((task) => {
        const result = queue.current.then(task)
        queue.current = result.catch(() => {})
        return result
    }, [])

    const apply = useCallback((payload) => {
        if (payload?.cart) {
            cartId.current = payload.cart.id
            setCart(payload.cart)
        }
        const message = payload?.userErrors?.[0]?.message
        if (message) {
            showAlert(message)
            return false
        }
        return Boolean(payload?.cart)
    }, [])

    const addToCart = useCallback(
        async (variantId) => {
            setAdding(true)
            try {
                const lines = [{ merchandiseId: variantId, quantity: 1 }]
                const ok = await enqueue(async () => {
                    if (cartId.current) {
                        const data = await gql("CartLinesAdd", { cartId: cartId.current, lines })
                        return apply(data.cartLinesAdd)
                    }
                    const data = await gql("CartCreate", { lines })
                    return apply(data.cartCreate)
                })
                if (ok) selectTab("cart")
            } catch {
                showAlert(NETWORK_MESSAGE)
            } finally {
                setAdding(false)
            }
        },
        [apply, enqueue, selectTab]
    )

    const changeQuantity = useCallback(
        (line, delta) => {
            const base = requested.current[line.id] ?? line.quantity
            const quantity = Math.max(0, base + delta)
            if (quantity === base) return
            requested.current[line.id] = quantity
            enqueue(async () => {
                const data = await gql("CartLinesUpdate", {
                    cartId: cartId.current,
                    lines: [{ id: line.id, quantity }],
                })
                apply(data.cartLinesUpdate)
            })
                .catch(() => showAlert(NETWORK_MESSAGE))
                .finally(() => {
                    if (requested.current[line.id] === quantity) delete requested.current[line.id]
                })
        },
        [apply, enqueue]
    )

    return useMemo(() => ({ cart, adding, addToCart, changeQuantity }), [cart, adding, addToCart, changeQuantity])
}
