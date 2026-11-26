#!/usr/bin/env node
// Test helper, a stand-in for the benchmark's replay server:
// forwards POST /api on 0.0.0.0:<port> to the mock.shop endpoint.
// Query responses are cached by request body; mutations always go upstream.
// Upstream failures are retried, so a flaky network does not fail a test run.
// Usage: node scripts/forward-server.mjs <port> [target]
import http from "node:http"

const port = Number(process.argv[2] || 8788)
const target = process.argv[3] || "https://apparel-large-catalog.mock.shop/api"
const cache = new Map()

async function upstream(body) {
    let lastError
    for (let attempt = 0; attempt < 4; attempt++) {
        try {
            const res = await fetch(target, { method: "POST", headers: { "Content-Type": "application/json" }, body })
            const text = await res.text()
            if (res.ok) return { status: res.status, text }
            lastError = new Error(`HTTP ${res.status}`)
        } catch (e) {
            lastError = e
        }
    }
    throw lastError
}

http.createServer(async (req, res) => {
    const chunks = []
    for await (const c of req) chunks.push(c)
    const body = Buffer.concat(chunks).toString()
    const isQuery = !/"operationName"\s*:\s*"Cart/.test(body)
    try {
        let result = isQuery ? cache.get(body) : undefined
        if (!result) {
            result = await upstream(body)
            if (isQuery) cache.set(body, result)
        }
        res.writeHead(result.status, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" })
        res.end(result.text)
    } catch (e) {
        res.writeHead(502)
        res.end(String(e))
    }
}).listen(port, "0.0.0.0", () => console.log(`forwarding :${port} -> ${target}`))
