package dev.whiskerrs.shopbench.catalyst;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.View;
import android.widget.FrameLayout;
import android.view.WindowInsets;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Hosts the Catalyst web build (bundled under assets/www) in a WebView.
 *
 * - https://appassets.androidplatform.net/... is served from assets/www, so nothing
 *   but API and image requests touch the network.
 * - EverbloomAndroid.postGraphQL sends the Storefront POST natively, to
 *   BuildConfig.SHOP_API_URL (set at build time).
 * - NativeBridge.openInBrowser implements Catalyst's bridge command of that name.
 */
public class MainActivity extends Activity {
    private static final String HOST = "appassets.androidplatform.net";
    private static final String START_URL = "https://" + HOST + "/";
    private static boolean homeReadyLogged = false;

    private final ExecutorService network = Executors.newFixedThreadPool(4);
    private final Handler main = new Handler(Looper.getMainLooper());
    private WebView webView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        webView = new WebView(this);
        webView.setBackgroundColor(Color.WHITE);
        webView.setOverScrollMode(View.OVER_SCROLL_NEVER);
        webView.setVerticalScrollBarEnabled(false);
        webView.setHorizontalScrollBarEnabled(false);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(false);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setSupportZoom(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);

        webView.addJavascriptInterface(new ShopBridge(), "EverbloomAndroid");
        webView.addJavascriptInterface(new CatalystBridge(), "NativeBridge");
        webView.setWebChromeClient(new WebChromeClient());
        webView.setWebViewClient(new AssetClient());

        // Keep content clear of the system bars (edge-to-edge is enforced on Android 15+).
        // A WebView ignores its own padding, so the insets pad a container instead.
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.WHITE);
        root.addView(webView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        root.setOnApplyWindowInsetsListener((v, insets) -> {
            int top, bottom, left, right;
            if (Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.ime());
                top = bars.top; bottom = bars.bottom; left = bars.left; right = bars.right;
            } else {
                top = insets.getSystemWindowInsetTop(); bottom = insets.getSystemWindowInsetBottom();
                left = insets.getSystemWindowInsetLeft(); right = insets.getSystemWindowInsetRight();
            }
            v.setPadding(left, top, right, bottom);
            return insets;
        });
        if (Build.VERSION.SDK_INT >= 30) {
            getWindow().getInsetsController().setSystemBarsAppearance(
                    android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                            | android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
                    android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                            | android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS);
        }

        setContentView(root);
        webView.loadUrl(START_URL);
    }

    @Override
    @SuppressWarnings("deprecation")
    public void onBackPressed() {
        webView.evaluateJavascript("window.__everbloomBack ? window.__everbloomBack() : false", value -> {
            if (!"true".equals(value)) MainActivity.super.onBackPressed();
        });
    }

    @Override
    protected void onDestroy() {
        network.shutdownNow();
        webView.destroy();
        super.onDestroy();
    }

    /** Serves https://appassets.androidplatform.net/<path> from assets/www. */
    private final class AssetClient extends WebViewClient {
        @Override
        public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
            Uri url = request.getUrl();
            if (!HOST.equals(url.getHost())) return null;
            String path = url.getPath() == null ? "" : url.getPath();
            if (path.startsWith("/")) path = path.substring(1);
            if (path.isEmpty() || path.lastIndexOf('.') < path.lastIndexOf('/') + 1) path = "index.html";
            if (path.contains("..")) return notFound();
            try {
                InputStream in = getAssets().open("www/" + path);
                return new WebResourceResponse(mimeType(path), "utf-8", in);
            } catch (IOException e) {
                return notFound();
            }
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            // The app is a single page; nothing else may load in the WebView.
            return !HOST.equals(request.getUrl().getHost());
        }

        private WebResourceResponse notFound() {
            WebResourceResponse r = new WebResourceResponse("text/plain", "utf-8", null);
            r.setStatusCodeAndReasonPhrase(404, "Not Found");
            return r;
        }

        private String mimeType(String path) {
            if (path.endsWith(".html")) return "text/html";
            if (path.endsWith(".js") || path.endsWith(".mjs")) return "text/javascript";
            if (path.endsWith(".css")) return "text/css";
            if (path.endsWith(".json")) return "application/json";
            if (path.endsWith(".svg")) return "image/svg+xml";
            if (path.endsWith(".png")) return "image/png";
            if (path.endsWith(".jpg") || path.endsWith(".jpeg")) return "image/jpeg";
            if (path.endsWith(".woff2")) return "font/woff2";
            return "application/octet-stream";
        }
    }

    /** Storefront transport and the benchmark log marker. */
    private final class ShopBridge {
        @JavascriptInterface
        public void postGraphQL(final int id, final String body) {
            network.execute(() -> {
                boolean ok = false;
                int status = 0;
                String text;
                HttpURLConnection conn = null;
                try {
                    conn = (HttpURLConnection) new URL(BuildConfig.SHOP_API_URL).openConnection();
                    conn.setRequestMethod("POST");
                    conn.setConnectTimeout(30000);
                    conn.setReadTimeout(30000);
                    conn.setUseCaches(false);
                    conn.setDoOutput(true);
                    conn.setRequestProperty("Content-Type", "application/json");
                    try (OutputStream out = conn.getOutputStream()) {
                        out.write(body.getBytes(StandardCharsets.UTF_8));
                    }
                    status = conn.getResponseCode();
                    InputStream in = status >= 400 ? conn.getErrorStream() : conn.getInputStream();
                    text = in == null ? "" : readAll(in);
                    ok = true;
                } catch (IOException e) {
                    text = e.getMessage() == null ? "Network error" : e.getMessage();
                } finally {
                    if (conn != null) conn.disconnect();
                }
                final String script = "window.__everbloomApiReply(" + id + "," + ok + "," + status + ","
                        + JSONObject.quote(text) + ")";
                main.post(() -> webView.evaluateJavascript(script, null));
            });
        }

        @JavascriptInterface
        public void homeReady() {
            if (homeReadyLogged) return;
            homeReadyLogged = true;
            Log.i("SHOPBENCH", "SHOPBENCH home_ready");
        }
    }

    /** Catalyst bridge commands used by the app. */
    private final class CatalystBridge {
        @JavascriptInterface
        public void openInBrowser(String url) {
            if (url == null || !(url.startsWith("https://") || url.startsWith("http://"))) return;
            main.post(() -> startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url))));
        }
    }

    private static String readAll(InputStream in) throws IOException {
        try (InputStream input = in) {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buf = new byte[16384];
            int n;
            while ((n = input.read(buf)) != -1) out.write(buf, 0, n);
            return out.toString("UTF-8");
        }
    }
}
