#!/usr/bin/env node
// Builds the Catalyst web app and packages it for the native shells.
//
// 1. `catalyst build` (production client + SSR bundles).
// 2. `catalyst serve`, then fetch "/" once: the server-rendered Home skeleton
//    becomes the bundled index.html, so the first frame needs no network and no JS.
// 3. Copy index.html and build/client/assets into www/, then into
//    ios/Everbloom/www and android/app/src/main/assets/www.
import { spawn, spawnSync } from "node:child_process"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const config = JSON.parse(fs.readFileSync(path.join(root, "config/config.json"), "utf8"))
const port = config.NODE_SERVER_PORT
const catalyst = path.join(root, "node_modules/.bin/catalyst")

function run(cmd, args) {
    const res = spawnSync(cmd, args, { cwd: root, stdio: "inherit" })
    if (res.status !== 0) throw new Error(`${cmd} ${args.join(" ")} failed`)
}

async function fetchShell() {
    const server = spawn(catalyst, ["serve"], { cwd: root, stdio: ["ignore", "pipe", "pipe"], detached: true })
    let log = ""
    server.stdout.on("data", (d) => (log += d))
    server.stderr.on("data", (d) => (log += d))
    try {
        for (let i = 0; i < 120; i++) {
            try {
                // The native-WebView header makes Catalyst render the page as it would for its own shells.
                const res = await fetch(`http://localhost:${port}/`, { headers: { "X-Catalyst-Native-WebView": "1" } })
                if (res.ok) return await res.text()
            } catch {
                // not up yet
            }
            if (server.exitCode !== null) break
            await new Promise((r) => setTimeout(r, 250))
        }
        throw new Error(`catalyst serve did not answer on port ${port}\n${log}`)
    } finally {
        try {
            process.kill(-server.pid, "SIGTERM")
        } catch {
            // already gone
        }
    }
}

function copyDir(from, to) {
    fs.rmSync(to, { recursive: true, force: true })
    fs.mkdirSync(path.dirname(to), { recursive: true })
    fs.cpSync(from, to, { recursive: true })
}

run(catalyst, ["build"])
const html = await fetchShell()
if (/https?:\/\/localhost/.test(html)) throw new Error("index.html still references the local server")

const www = path.join(root, "build", "www")
fs.rmSync(www, { recursive: true, force: true })
fs.mkdirSync(www, { recursive: true })
fs.writeFileSync(path.join(www, "index.html"), html)
copyDir(path.join(root, "build", "client", "assets"), path.join(www, "assets", "client", "assets"))

for (const target of ["ios/Everbloom/www", "android/app/src/main/assets/www"]) {
    copyDir(www, path.join(root, target))
}
console.log(`\nPackaged the web app into ios/Everbloom/www and android/app/src/main/assets/www`)
