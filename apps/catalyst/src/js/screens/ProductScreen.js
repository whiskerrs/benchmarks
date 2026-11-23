import React, { useMemo, useRef, useState } from "react"
import { useNav } from "../lib/nav"
import { useCart } from "../lib/cart"
import { useQuery } from "../lib/useQuery"
import { IMG, money } from "../lib/format"
import { BackButton, ErrorState, Img, Price } from "../components/ui"

const isDefaultTitleOption = (o) =>
    o.name === "Title" && o.optionValues.length === 1 && o.optionValues[0].name === "Default Title"

const initialVariant = (variants) => variants.find((v) => v.availableForSale) || variants[0] || null

function Carousel({ images }) {
    const ref = useRef(null)
    const [index, setIndex] = useState(0)
    const onScroll = () => {
        const el = ref.current
        const i = Math.round(el.scrollLeft / el.clientWidth)
        if (i !== index) setIndex(i)
    }
    const show = (i) => {
        const el = ref.current
        el.scrollTo({ left: i * el.clientWidth })
    }
    return (
        <div className="pdp-media">
            <div ref={ref} className="pdp-carousel" role="group" aria-label="product-carousel" onScroll={onScroll}>
                {images.map((img, i) => (
                    <Img key={img.url + i} className="pdp-img" url={img.url} width={IMG.carousel} />
                ))}
            </div>
            {images.length > 1 && (
                <div className="dots">
                    {images.map((img, i) => (
                        <button
                            key={img.url + i}
                            type="button"
                            className="dot-btn"
                            aria-label={`Show image ${i + 1}`}
                            onClick={() => show(i)}
                        >
                            <span className={i === index ? "dot active" : "dot"} />
                        </button>
                    ))}
                </div>
            )}
        </div>
    )
}

function Options({ options, variant, variants, onSelect }) {
    const selected = Object.fromEntries(variant.selectedOptions.map((o) => [o.name, o.value]))
    const choose = (name, value) => {
        const want = { ...selected, [name]: value }
        const hasValue = (v) => v.selectedOptions.some((o) => o.name === name && o.value === value)
        const match =
            variants.find((v) => v.selectedOptions.every((o) => want[o.name] === o.value)) ||
            variants.find((v) => hasValue(v) && v.availableForSale) ||
            variants.find(hasValue)
        if (match) onSelect(match)
    }
    return options.map((option) => (
        <fieldset key={option.name} className="option">
            <legend className="option-label">
                {option.name}: <span className="option-value">{selected[option.name]}</span>
            </legend>
            <div className="pills">
                {option.optionValues.map(({ name }) => (
                    <button
                        key={name}
                        type="button"
                        aria-label={`option-${option.name}-${name}`}
                        className={selected[option.name] === name ? "pill selected" : "pill"}
                        onClick={() => choose(option.name, name)}
                    >
                        {name}
                    </button>
                ))}
            </div>
        </fieldset>
    ))
}

function ProductContent({ product, recommendations }) {
    const { push } = useNav()
    const { adding, addToCart } = useCart()
    const variants = product.variants.nodes
    const [variant, setVariant] = useState(() => initialVariant(variants))
    const options = useMemo(() => product.options.filter((o) => !isDefaultTitleOption(o)), [product.options])

    return (
        <>
            <div className="scroll pdp-scroll">
                <Carousel images={product.images.nodes} />
                <div className="pdp-head">
                    <h1 className="pdp-title">{product.title}</h1>
                    {variant && <Price price={variant.price} compare={variant.compareAtPrice} className="pdp-price" />}
                </div>
                {variant && <Options options={options} variant={variant} variants={variants} onSelect={setVariant} />}
                <section className="pdp-section">
                    <h2 className="h3">Description</h2>
                    <p className="pdp-description">{product.description}</p>
                </section>
                {recommendations.length > 0 && (
                    <section className="section">
                        <h2 className="h2 mb12 px16">You may also like</h2>
                        <div className="carousel">
                            {recommendations.map((p, i) => (
                                <button
                                    key={p.id}
                                    type="button"
                                    className="rec-card"
                                    aria-label={`recommendation-${i}`}
                                    onClick={() => push({ type: "product", handle: p.handle })}
                                >
                                    <Img className="rec-img" url={p.featuredImage?.url} width={IMG.card} />
                                    <span className="card-title">{p.title}</span>
                                    <span className="rec-price">{money(p.priceRange?.minVariantPrice)}</span>
                                </button>
                            ))}
                        </div>
                    </section>
                )}
                <div className="pdp-bottom-space" />
            </div>
            <div className="buy-bar">
                <button
                    type="button"
                    className="btn-primary"
                    aria-label="add-to-cart"
                    disabled={adding || !variant}
                    onClick={() => addToCart(variant.id)}
                >
                    Add to cart · {money(variant?.price)}
                </button>
            </div>
        </>
    )
}

const Skeleton = () => (
    <div className="scroll pdp-scroll" aria-hidden="true">
        <div className="sk pdp-media" />
        <div className="pdp-head">
            <div className="sk sk-title" />
            <div className="sk sk-price" />
        </div>
        <div className="pdp-section">
            <div className="sk sk-line" />
            <div className="sk sk-line" />
            <div className="sk sk-line short" />
        </div>
    </div>
)

export default function ProductScreen({ handle }) {
    const { pop } = useNav()
    const { data, error, retry } = useQuery("Product", { handle })

    let body
    if (data?.product) body = <ProductContent product={data.product} recommendations={data.productRecommendations || []} />
    else if (error || data) body = <div className="pdp-error"><ErrorState onRetry={retry} /></div>
    else body = <Skeleton />

    return (
        <div className="screen">
            {body}
            <BackButton className="pdp-back" onClick={pop} />
        </div>
    )
}
