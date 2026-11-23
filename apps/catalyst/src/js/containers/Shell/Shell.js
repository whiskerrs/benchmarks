import React, { memo, useEffect, useMemo, useReducer } from "react"
import { gql } from "../../api/graphql"
import { NavContext, TABS, initialNav, navReducer } from "../../lib/nav"
import { CartContext, useCartStore } from "../../lib/cart"
import { CartIcon, HomeIcon, SearchIcon } from "../../components/Icons"
import HomeScreen from "../../screens/HomeScreen"
import CollectionScreen from "../../screens/CollectionScreen"
import ProductScreen from "../../screens/ProductScreen"
import SearchScreen from "../../screens/SearchScreen"
import CartScreen from "../../screens/CartScreen"

const SCREENS = {
    home: HomeScreen,
    collection: CollectionScreen,
    product: ProductScreen,
    search: SearchScreen,
    cart: CartScreen,
}

const TAB_META = {
    home: { label: "Home", Icon: HomeIcon },
    search: { label: "Search", Icon: SearchIcon },
    cart: { label: "Cart", Icon: CartIcon },
}

/** One stack entry. Memoised so hidden screens do not re-render on navigation. */
const StackEntry = memo(function StackEntry({ entry, visible }) {
    const Screen = SCREENS[entry.type]
    return (
        <div className={visible ? "layer" : "layer hidden"} aria-hidden={visible ? undefined : true}>
            <Screen {...entry} />
        </div>
    )
})

function TabBar({ tab, count, onSelect }) {
    return (
        <nav className="tabbar">
            {TABS.map((t) => {
                const { label, Icon } = TAB_META[t]
                return (
                    <button
                        key={t}
                        type="button"
                        className={t === tab ? "tab active" : "tab"}
                        aria-label={`tab-${t}`}
                        onClick={() => onSelect(t)}
                    >
                        <Icon />
                        {label}
                    </button>
                )
            })}
            {count > 0 && (
                <span className="badge" role="text" aria-label="cart-badge">
                    {count}
                </span>
            )}
        </nav>
    )
}

/**
 * The "/" route: the whole app. Home's data is this route's Catalyst
 * clientFetcher (read in HomeScreen with useCurrentRouteData); the other
 * screens are pushed onto in-memory tab stacks.
 */
function Shell() {
    const [nav, dispatch] = useReducer(navReducer, initialNav)
    const actions = useMemo(
        () => ({
            push: (screen) => dispatch({ type: "push", screen }),
            pop: () => dispatch({ type: "pop" }),
            selectTab: (tab) => dispatch({ type: "tab", tab }),
        }),
        []
    )
    const cart = useCartStore(actions.selectTab)

    // Android hardware back: pop the current stack; false lets the shell exit.
    const canPop = nav.stacks[nav.tab].length > 1
    useEffect(() => {
        window.__everbloomBack = () => {
            if (!canPop) return false
            actions.pop()
            return true
        }
    }, [canPop, actions])

    const top = nav.stacks[nav.tab][nav.stacks[nav.tab].length - 1]
    const showTabs = top.type !== "product"

    return (
        <NavContext.Provider value={actions}>
            <CartContext.Provider value={cart}>
                <div className="app">
                    {TABS.map((t) => {
                        const stack = nav.stacks[t]
                        return stack.map((entry, i) => (
                            <StackEntry key={entry.id} entry={entry} visible={t === nav.tab && i === stack.length - 1} />
                        ))
                    })}
                    {showTabs && (
                        <TabBar tab={nav.tab} count={cart.cart?.totalQuantity || 0} onSelect={actions.selectTab} />
                    )}
                </div>
            </CartContext.Provider>
        </NavContext.Provider>
    )
}

Shell.clientFetcher = () => gql("Home")

export default Shell
