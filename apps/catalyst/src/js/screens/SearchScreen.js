import React, { useCallback, useEffect, useState } from "react"
import { gql } from "../api/graphql"
import { useNav } from "../lib/nav"
import { usePaged } from "../lib/usePaged"
import { IMG, money } from "../lib/format"
import { ErrorState, Img, Spinner } from "../components/ui"
import { VirtualList } from "../components/Virtual"
import { SearchIcon } from "../components/Icons"

const DEBOUNCE_MS = 300
const ROW_HEIGHT = 101 // 85 thumbnail + 2 × 8 padding

export default function SearchScreen() {
    const { push } = useNav()
    const [text, setText] = useState("")
    const [query, setQuery] = useState("")

    // Send the query 300 ms after the user stops typing.
    useEffect(() => {
        const t = setTimeout(() => setQuery(text.trim()), DEBOUNCE_MS)
        return () => clearTimeout(t)
    }, [text])

    const fetchPage = useCallback(
        async (after) => {
            const data = await gql("Search", { query, first: 24, after })
            return { ...data.search, meta: { totalCount: data.search.totalCount } }
        },
        [query]
    )
    // usePaged discards responses for a query that is no longer current.
    const page = usePaged(query ? query : null, fetchPage)
    const open = useCallback((p) => push({ type: "product", handle: p.handle }), [push])

    const renderItem = useCallback(
        (i, style) => {
            const p = page.items[i]
            return (
                <button key={i} type="button" className="result" aria-label={`search-result-${i}`} style={style} onClick={() => open(p)}>
                    <Img className="result-img" url={p.featuredImage?.url} width={IMG.thumb} />
                    <span className="result-text">
                        <span className="result-title">{p.title}</span>
                        <span className="price">{money(p.priceRange?.minVariantPrice)}</span>
                    </span>
                </button>
            )
        },
        [page.items, open]
    )

    let body
    if (!text.trim()) body = <div className="search-hint">Search across 995 products by name.</div>
    else if (page.status === "error") body = <ErrorState onRetry={page.retry} />
    else if (page.status === "ready" || page.status === "loadingMore" || page.status === "errorMore") {
        let footer = null
        if (page.status === "loadingMore") footer = <Spinner />
        else if (page.status === "errorMore")
            footer = (
                <button type="button" className="btn-secondary" aria-label="error-retry" onClick={page.retry}>
                    Retry
                </button>
            )
        body = (
            <>
                <p className="result-count">{`${page.meta?.totalCount ?? 0} results`}</p>
                <VirtualList
                    key={query}
                    id="search-results"
                    rowHeight={ROW_HEIGHT}
                    count={page.items.length}
                    renderItem={renderItem}
                    onEndReached={page.loadMore}
                    footer={footer}
                />
            </>
        )
    } else
        body = (
            <div className="center-spinner">
                <Spinner />
            </div>
        )

    return (
        <div className="screen with-tabs">
            <div className="search-bar">
                <label className="search-field">
                    <SearchIcon size={20} />
                    <input
                        type="search"
                        aria-label="search-input"
                        placeholder="Search products"
                        autoComplete="off"
                        autoCorrect="off"
                        autoCapitalize="none"
                        spellCheck="false"
                        enterKeyHint="search"
                        value={text}
                        onChange={(e) => setText(e.target.value)}
                        onKeyDown={(e) => e.key === "Enter" && e.currentTarget.blur()}
                    />
                </label>
            </div>
            {body}
        </div>
    )
}
