// Small hooks into the native shells (see ios/ and android/).

let homeReadySent = false

/** Writes `SHOPBENCH home_ready` to the platform log, once per process. */
export function signalHomeReady() {
    if (homeReadySent || typeof window === "undefined") return
    homeReadySent = true
    window.webkit?.messageHandlers?.shopbench?.postMessage("home_ready")
    window.EverbloomAndroid?.homeReady?.()
}

/** Shows a native alert; window.alert is routed to the platform dialog by the shells. */
export function showAlert(message) {
    window.alert(message)
}

/**
 * Opens a URL with Catalyst's `openInBrowser` bridge command (the command behind
 * `useIntent().openInBrowser`), sent with Catalyst's bridge protocol directly:
 * importing `catalyst-core/hooks` would bundle every native hook (camera, video,
 * AI) into the startup JavaScript.
 */
export function openInBrowser(url) {
    if (window.webkit?.messageHandlers?.NativeBridge) {
        window.webkit.messageHandlers.NativeBridge.postMessage({ command: "openInBrowser", data: url })
    } else if (window.NativeBridge?.openInBrowser) {
        window.NativeBridge.openInBrowser(url)
    } else {
        window.open(url, "_blank")
    }
}
