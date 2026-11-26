// Shared building blocks.
//
// Benchmark identifiers: WKWebView exposes no DOM attribute as an XCUITest
// accessibilityIdentifier, but XCUITest's identifier queries (`app.buttons["x"]`,
// `descendants(matching: .any)["x"]`) also match the accessibility label. So each
// identifier is set as `aria-label`: on buttons, on `role="group"` containers, and on
// `role="text"` values (whose visible text then becomes the element's value).
import React from "react"
import { money, sized, compareAt, IMG } from "../lib/format"
import { AlertIcon, BackIcon } from "./Icons"

export const Img = ({ url, width, className }) => (
    <img className={className} src={sized(url, width)} alt="" decoding="async" draggable="false" />
)

export const Price = ({ price, compare, className = "price" }) => {
    const higher = compareAt(price, compare)
    return (
        <span className="price-row">
            <span className={higher ? `${className} sale` : className}>{money(price)}</span>
            {higher && <s className="compare">{money(higher)}</s>}
        </span>
    )
}

/** Grid card used by Home best sellers and the Collection grid. */
export const ProductCard = ({ product, id, onOpen, style }) => (
    <button type="button" className="card" aria-label={id} style={style} onClick={() => onOpen(product)}>
        <Img className="card-img" url={product.featuredImage?.url} width={IMG.card} />
        <span className="card-title">{product.title}</span>
        <Price price={product.priceRange?.minVariantPrice} compare={product.compareAtPriceRange?.minVariantPrice} />
    </button>
)

export const BackButton = ({ onClick, className = "nav-back" }) => (
    <button type="button" className={className} aria-label="back" onClick={onClick}>
        <BackIcon size={className === "nav-back" ? 24 : 22} />
    </button>
)

export const ErrorState = ({ onRetry }) => (
    <div className="state">
        <AlertIcon />
        <span className="state-title">Couldn&apos;t load products</span>
        <span className="state-text">Check your connection and try again.</span>
        <button type="button" className="btn-secondary" aria-label="error-retry" onClick={onRetry}>
            Retry
        </button>
    </div>
)

export const Spinner = () => <span className="spinner" role="progressbar" aria-label="Loading" />

export const SkeletonGrid = ({ count = 6 }) => (
    <div className="grid" aria-hidden="true">
        {Array.from({ length: count }, (_, i) => (
            <div key={i} className="card">
                <div className="sk card-img" />
                <div className="sk sk-line" />
                <div className="sk sk-line short" />
            </div>
        ))}
    </div>
)
