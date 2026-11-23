import React, { useCallback, useState } from "react"
import { gql } from "../api/graphql"
import { useNav } from "../lib/nav"
import { usePaged } from "../lib/usePaged"
import { BackButton, ErrorState, ProductCard, SkeletonGrid, Spinner } from "../components/ui"
import { VirtualGrid } from "../components/Virtual"

const SORTS = [
    { id: "sort-featured", label: "Featured", sortKey: "COLLECTION_DEFAULT", reverse: false },
    { id: "sort-best-selling", label: "Best selling", sortKey: "BEST_SELLING", reverse: false },
    { id: "sort-price-asc", label: "Price: low to high", sortKey: "PRICE", reverse: false },
    { id: "sort-price-desc", label: "Price: high to low", sortKey: "PRICE", reverse: true },
]

export default function CollectionScreen({ handle, title }) {
    const { push, pop } = useNav()
    const [sort, setSort] = useState(SORTS[0])

    const fetchPage = useCallback(
        async (after) => {
            const data = await gql("CollectionProducts", {
                handle,
                first: 24,
                after,
                sortKey: sort.sortKey,
                reverse: sort.reverse,
            })
            const c = data.collection
            if (!c) throw new Error("Collection not found")
            return { ...c.products, meta: { title: c.title, description: c.description } }
        },
        [handle, sort]
    )
    const page = usePaged(`${handle}|${sort.id}`, fetchPage)
    const openProduct = useCallback((p) => push({ type: "product", handle: p.handle }), [push])

    const renderItem = useCallback(
        (i, style) => (
            <ProductCard key={i} product={page.items[i]} id={`product-card-${i}`} onOpen={openProduct} style={style} />
        ),
        [page.items, openProduct]
    )

    let footer = null
    if (page.status === "loadingMore") footer = <Spinner />
    else if (page.status === "errorMore")
        footer = (
            <button type="button" className="btn-secondary" aria-label="error-retry" onClick={page.retry}>
                Retry
            </button>
        )

    return (
        <div className="screen with-tabs">
            <header className="navbar">
                <BackButton onClick={pop} />
                <span className="navbar-title">{page.meta?.title || title}</span>
                <span />
            </header>
            {page.meta?.description ? <p className="description">{page.meta.description}</p> : null}
            <div className="sorts">
                {SORTS.map((s) => (
                    <button
                        key={s.id}
                        type="button"
                        aria-label={s.id}
                        className={s.id === sort.id ? "sort selected" : "sort"}
                        onClick={() => s.id !== sort.id && setSort(s)}
                    >
                        {s.label}
                    </button>
                ))}
            </div>
            {page.status === "error" ? (
                <ErrorState onRetry={page.retry} />
            ) : page.status === "loading" || page.status === "idle" ? (
                <div className="scroll" role="group" aria-label="product-grid">
                    <SkeletonGrid />
                </div>
            ) : (
                <VirtualGrid
                    key={sort.id}
                    id="product-grid"
                    count={page.items.length}
                    renderItem={renderItem}
                    onEndReached={page.loadMore}
                    footer={footer}
                />
            )}
        </div>
    )
}
