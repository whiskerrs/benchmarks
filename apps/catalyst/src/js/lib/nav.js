// In-memory tab + stack navigation.
//
// Each tab keeps its own stack of screen entries; switching tabs keeps every
// stack. All entries stay mounted (hidden when not on top), so a screen keeps
// its data and scroll position when the user comes back to it.
import { createContext, useContext } from "react"

export const TABS = ["home", "search", "cart"]

let nextId = 3

export const initialNav = {
    tab: "home",
    stacks: {
        home: [{ id: 0, type: "home" }],
        search: [{ id: 1, type: "search" }],
        cart: [{ id: 2, type: "cart" }],
    },
}

export function navReducer(state, action) {
    switch (action.type) {
        case "push": {
            const stack = state.stacks[state.tab]
            const entry = { ...action.screen, id: nextId++ }
            return { ...state, stacks: { ...state.stacks, [state.tab]: [...stack, entry] } }
        }
        case "pop": {
            const stack = state.stacks[state.tab]
            if (stack.length < 2) return state
            return { ...state, stacks: { ...state.stacks, [state.tab]: stack.slice(0, -1) } }
        }
        case "tab":
            return state.tab === action.tab ? state : { ...state, tab: action.tab }
        default:
            return state
    }
}

/** { push(screen), pop(), selectTab(tab) } — stable across renders. */
export const NavContext = createContext(null)
export const useNav = () => useContext(NavContext)
