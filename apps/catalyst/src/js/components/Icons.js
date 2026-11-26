import React from "react"

const base = {
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeLinecap: "round",
    strokeLinejoin: "round",
    "aria-hidden": true,
}

export const HomeIcon = () => (
    <svg width="24" height="24" strokeWidth="1.75" {...base}>
        <path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z" />
    </svg>
)

export const SearchIcon = ({ size = 24 }) => (
    <svg width={size} height={size} strokeWidth="1.75" {...base}>
        <circle cx="11" cy="11" r="7" />
        <path d="m20 20-3.5-3.5" />
    </svg>
)

export const CartIcon = ({ size = 24, strokeWidth = 1.75 }) => (
    <svg width={size} height={size} strokeWidth={strokeWidth} {...base}>
        <path d="M6 7h12l-1 13H7z" />
        <path d="M9 7a3 3 0 0 1 6 0" />
    </svg>
)

export const BackIcon = ({ size = 24 }) => (
    <svg width={size} height={size} strokeWidth="1.75" {...base}>
        <path d="m15 5-7 7 7 7" />
    </svg>
)

export const MinusIcon = () => (
    <svg width="16" height="16" strokeWidth="2" {...base}>
        <path d="M5 12h14" />
    </svg>
)

export const PlusIcon = () => (
    <svg width="16" height="16" strokeWidth="2" {...base}>
        <path d="M12 5v14M5 12h14" />
    </svg>
)

export const AlertIcon = () => (
    <svg width="48" height="48" strokeWidth="1.25" {...base} stroke="#6E6A63">
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7.5v5.5" />
        <path d="M12 16.5h.01" />
    </svg>
)
