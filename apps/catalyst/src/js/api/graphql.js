// Storefront GraphQL over plain HTTP POST.
//
// The operations come verbatim from storefront.graphql (a copy of
// spec/storefront.graphql). Each request sends one operation plus the
// fragments it uses, with `operationName` always set.
//
// Transport:
// - iOS shell: `webkit.messageHandlers.shopApi` sends the POST natively, to the
//   endpoint from the SHOP_API_URL launch environment variable.
// - Android shell: `EverbloomAndroid.postGraphQL` does the same, with the
//   endpoint fixed at build time.
// - Plain browser (catalyst start / serve): fetch() to the default endpoint.
import source from "./storefront.graphql?raw"

export const DEFAULT_ENDPOINT = "https://apparel-large-catalog.mock.shop/api"
const TIMEOUT_MS = 30000

function splitDefinitions(text) {
    const defs = {}
    let depth = 0
    let start = -1
    for (let i = 0; i < text.length; i++) {
        const c = text[i]
        if (start === -1 && !/\s/.test(c)) start = i
        if (c === "{") depth++
        else if (c === "}") {
            depth--
            if (depth === 0) {
                const def = text.slice(start, i + 1)
                const [, kind, name] = def.match(/^(query|mutation|fragment)\s+(\w+)/)
                defs[name] = { kind, text: def }
                start = -1
            }
        }
    }
    return defs
}

const definitions = splitDefinitions(source)

function documentFor(operationName) {
    const included = []
    const visit = (name) => {
        if (included.includes(name)) return
        included.push(name)
        const spreads = definitions[name].text.matchAll(/\.\.\.\s*([A-Za-z_]\w*)/g)
        for (const [, ref] of spreads) if (ref !== "on" && definitions[ref]) visit(ref)
    }
    visit(operationName)
    return included.map((name) => definitions[name].text).join("\n\n")
}

const documents = {}
for (const [name, def] of Object.entries(definitions)) {
    if (def.kind !== "fragment") documents[name] = documentFor(name)
}

let androidSeq = 0
const androidPending = new Map()

if (typeof window !== "undefined") {
    window.__everbloomApiReply = (id, ok, status, body) => {
        const pending = androidPending.get(id)
        if (!pending) return
        androidPending.delete(id)
        if (ok) pending.resolve({ status, body })
        else pending.reject(new Error(body || "Network error"))
    }
}

function send(body) {
    const ios = window.webkit?.messageHandlers?.shopApi
    if (ios) return ios.postMessage(body)

    const android = window.EverbloomAndroid
    if (android) {
        return new Promise((resolve, reject) => {
            const id = ++androidSeq
            androidPending.set(id, { resolve, reject })
            android.postGraphQL(id, body)
        })
    }

    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)
    return fetch(DEFAULT_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
        signal: controller.signal,
    })
        .then(async (res) => ({ status: res.status, body: await res.text() }))
        .finally(() => clearTimeout(timer))
}

/** Runs a named operation from storefront.graphql and resolves with its `data`. */
export async function gql(operationName, variables = {}) {
    const query = documents[operationName]
    const body = JSON.stringify({ operationName, query, variables })
    const { status, body: text } = await send(body)
    if (status < 200 || status >= 300) throw new Error(`HTTP ${status}`)
    const json = JSON.parse(text)
    if (!json.data) throw new Error(json.errors?.[0]?.message || "Empty response")
    return json.data
}
