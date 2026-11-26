import { useCallback, useEffect, useRef, useState } from "react"

/**
 * Cursor pagination for a connection.
 *
 * `fetchPage(after)` resolves to { nodes, pageInfo, meta }. Changing `key`
 * reloads from the first page; responses for an older key are discarded.
 * With `key === null` nothing is loaded.
 */
export function usePaged(key, fetchPage) {
    const [state, setState] = useState({ items: [], meta: null, status: "idle", hasNext: false, cursor: null })
    const generation = useRef(0)
    const loading = useRef(false)
    const fetchRef = useRef(fetchPage)
    fetchRef.current = fetchPage

    const load = useCallback((after, reset) => {
        const gen = generation.current
        loading.current = true
        setState((s) => ({ ...s, status: reset ? "loading" : "loadingMore", ...(reset ? { items: [] } : {}) }))
        fetchRef.current(after).then(
            ({ nodes, pageInfo, meta }) => {
                if (gen !== generation.current) return
                loading.current = false
                setState((s) => ({
                    items: reset ? nodes : s.items.concat(nodes),
                    meta: meta ?? s.meta,
                    status: "ready",
                    hasNext: pageInfo.hasNextPage,
                    cursor: pageInfo.endCursor,
                }))
            },
            () => {
                if (gen !== generation.current) return
                loading.current = false
                setState((s) => ({ ...s, status: reset ? "error" : "errorMore" }))
            }
        )
    }, [])

    useEffect(() => {
        generation.current++
        loading.current = false
        if (key === null) {
            setState({ items: [], meta: null, status: "idle", hasNext: false, cursor: null })
            return
        }
        load(null, true)
    }, [key, load])

    const current = useRef(state)
    current.current = state

    const loadMore = useCallback(() => {
        const s = current.current
        if (!loading.current && s.status === "ready" && s.hasNext) load(s.cursor, false)
    }, [load])

    const retry = useCallback(() => {
        const s = current.current
        if (loading.current) return
        if (s.status === "error") load(null, true)
        else if (s.status === "errorMore") load(s.cursor, false)
    }, [load])

    return { ...state, loadMore, retry }
}
