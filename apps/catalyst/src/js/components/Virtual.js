// Windowed lists: only the rows on screen, plus a small buffer, are rendered.
// Catalyst has no list primitive, so this positions fixed-height rows absolutely
// inside a scroll container and renders the visible slice.
import React, { useCallback, useLayoutEffect, useRef, useState } from "react"

const OVERSCAN_ROWS = 2

function useWindow(scrollRef, rowCount, stride, offset) {
    const [range, setRange] = useState({ first: 0, last: -1 })
    const measure = useCallback(() => {
        const el = scrollRef.current
        if (!el || !stride) return
        const top = el.scrollTop - offset
        const first = Math.max(0, Math.floor(top / stride) - OVERSCAN_ROWS)
        const last = Math.min(rowCount - 1, Math.ceil((top + el.clientHeight) / stride) + OVERSCAN_ROWS)
        setRange((r) => (r.first === first && r.last === last ? r : { first, last }))
    }, [scrollRef, rowCount, stride, offset])
    useLayoutEffect(measure, [measure])
    return [range, measure]
}

function useWidth(ref) {
    const [width, setWidth] = useState(0)
    useLayoutEffect(() => {
        const read = () => ref.current && setWidth(ref.current.clientWidth)
        read()
        window.addEventListener("resize", read)
        return () => window.removeEventListener("resize", read)
    }, [ref])
    return width
}

/**
 * Scroll container with a windowed body.
 * - `layout(width)` returns { columns, stride, itemHeight, itemWidth, padX, gapX, padTop }
 * - `onEndReached` fires when the user is within one screen height of the end.
 */
function VirtualScroller({ id, className, count, layout, renderItem, footer, onEndReached, footerHeight = 64 }) {
    const ref = useRef(null)
    const width = useWidth(ref)
    const geo = width ? layout(width) : null
    const rows = geo ? Math.ceil(count / geo.columns) : 0
    const [range, measure] = useWindow(ref, rows, geo?.stride || 0, geo?.padTop || 0)

    const checkEnd = useCallback(() => {
        const el = ref.current
        if (!el || !onEndReached) return
        if (el.scrollHeight - el.scrollTop - el.clientHeight < el.clientHeight) onEndReached()
    }, [onEndReached])

    // Content shorter than the threshold (first page, or after a page arrives).
    useLayoutEffect(checkEnd, [checkEnd, count])

    const onScroll = () => {
        measure()
        checkEnd()
    }

    const bodyHeight = geo ? geo.padTop + rows * geo.stride : 0
    const items = []
    if (geo) {
        for (let row = range.first; row <= range.last; row++) {
            for (let col = 0; col < geo.columns; col++) {
                const index = row * geo.columns + col
                if (index >= count) break
                items.push(
                    renderItem(index, {
                        position: "absolute",
                        top: geo.padTop + row * geo.stride,
                        left: geo.padX + col * (geo.itemWidth + geo.gapX),
                        width: geo.itemWidth,
                        height: geo.itemHeight,
                    })
                )
            }
        }
    }

    return (
        <div ref={ref} className={`scroll ${className || ""}`} role="group" aria-label={id} onScroll={onScroll}>
            <div className="virtual-body" style={{ height: bodyHeight }}>
                {items}
            </div>
            {footer ? (
                <div className="list-footer" style={{ minHeight: footerHeight }}>
                    {footer}
                </div>
            ) : (
                <div className="list-end" />
            )}
        </div>
    )
}

const CARD_TEXT_HEIGHT = 8 + 36 + 8 + 20 // gap, two title lines, gap, price line

/** Two-column product grid (Collection). */
export const VirtualGrid = (props) => (
    <VirtualScroller
        {...props}
        layout={(width) => {
            const padX = 16
            const gapX = 12
            const itemWidth = (width - padX * 2 - gapX) / 2
            const itemHeight = (itemWidth * 4) / 3 + CARD_TEXT_HEIGHT
            return { columns: 2, padX, gapX, itemWidth, itemHeight, stride: itemHeight + 20, padTop: 0 }
        }}
    />
)

/** Single-column list of fixed-height rows (Search). */
export const VirtualList = ({ rowHeight, ...props }) => (
    <VirtualScroller
        {...props}
        layout={(width) => ({
            columns: 1,
            padX: 0,
            gapX: 0,
            itemWidth: width,
            itemHeight: rowHeight,
            stride: rowHeight,
            padTop: 0,
        })}
    />
)
