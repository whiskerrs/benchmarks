import React, { useEffect } from "react"
import { useCurrentRouteData } from "catalyst-core"
import { useNav } from "../lib/nav"
import { signalHomeReady } from "../lib/native"
import { IMG } from "../lib/format"
import { ErrorState, Img, ProductCard } from "../components/ui"

const Header = () => (
    <header className="home-header">
        <span className="wordmark">Everbloom</span>
    </header>
)

const Skeleton = () => (
    <div aria-hidden="true">
        <div className="chips">
            {[52, 110, 96, 80].map((w) => (
                <div key={w} className="sk sk-chip" style={{ width: w }} />
            ))}
        </div>
        <div className="sk featured" />
        <div className="section-head">
            <div className="sk sk-heading" />
        </div>
        <div className="carousel">
            {[0, 1, 2].map((i) => (
                <div key={i} className="sk collection-img" />
            ))}
        </div>
    </div>
)

function HomeContent({ data }) {
    const { push } = useNav()
    const collections = data.collections.nodes
    const products = data.products.nodes
    const featured = collections[0]
    const openCollection = (c) => push({ type: "collection", handle: c.handle, title: c.title })
    const openProduct = (p) => push({ type: "product", handle: p.handle })

    useEffect(() => {
        if (collections.length && products.length) signalHomeReady()
    }, [collections.length, products.length])

    return (
        <>
            <nav className="chips" aria-label="Collections">
                {collections.map((c, i) => (
                    <button
                        key={c.id}
                        type="button"
                        className="chip"
                        aria-label={`collection-chip-${i}`}
                        onClick={() => openCollection(c)}
                    >
                        {c.title}
                    </button>
                ))}
            </nav>
            {featured && (
                <button
                    type="button"
                    className="featured"
                    aria-label="featured-collection"
                    onClick={() => openCollection(featured)}
                >
                    <Img className="featured-img" url={featured.image?.url} width={IMG.banner} />
                    <span className="featured-overlay">
                        <span className="featured-label">Featured collection</span>
                        <span className="featured-title">{featured.title}</span>
                        <span className="featured-cta">Shop now</span>
                    </span>
                </button>
            )}
            <section className="section">
                <div className="section-head">
                    <h2 className="h2">Collections</h2>
                </div>
                <div className="carousel">
                    {collections.map((c, i) => (
                        <button
                            key={c.id}
                            type="button"
                            className="collection-card"
                            aria-label={`collection-card-${i}`}
                            onClick={() => openCollection(c)}
                        >
                            <Img className="collection-img" url={c.image?.url} width={IMG.card} />
                            <span className="collection-title">{c.title}</span>
                        </button>
                    ))}
                </div>
            </section>
            <section className="section padded">
                <h2 className="h2 mb12">Best sellers</h2>
                <div className="grid">
                    {products.map((p, i) => (
                        <ProductCard key={p.id} product={p} id={`best-seller-${i}`} onOpen={openProduct} />
                    ))}
                </div>
            </section>
        </>
    )
}

/** Home. Data comes from the "/" route's clientFetcher (Catalyst route data). */
export default function HomeScreen() {
    const { data, error, refetch } = useCurrentRouteData()

    let body
    if (data) body = <HomeContent data={data} />
    else if (error) body = <ErrorState onRetry={() => refetch()} />
    else body = <Skeleton />

    return (
        <div className="screen with-tabs">
            <div className={`scroll ${error && !data ? "column" : ""}`} role="group" aria-label="home-scroll">
                <Header />
                {body}
                <div className="list-end" />
            </div>
        </div>
    )
}
