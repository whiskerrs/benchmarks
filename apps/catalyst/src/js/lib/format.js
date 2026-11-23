/** "$" followed by the amount with two decimals: "75.0" -> "$75.00". */
export const money = (m) => (m ? `$${Number(m.amount).toFixed(2)}` : "")

/** Adds the `width` query parameter to an API image URL. */
export const sized = (url, width) => (url ? `${url}${url.includes("?") ? "&" : "?"}width=${width}` : undefined)

/** Compare-at price when it is higher than the price, else null. */
export const compareAt = (price, compare) =>
    compare && price && Number(compare.amount) > Number(price.amount) ? compare : null

export const IMG = { banner: 1080, carousel: 1080, card: 480, thumb: 240 }
