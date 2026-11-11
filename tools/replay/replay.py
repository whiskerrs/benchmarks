#!/usr/bin/env python3
"""Record-and-replay server for the Shopify Storefront API used by the benchmark apps.

  replay.py serve  [--data DIR] [--port N]           serve recordings only; misses return 404
  replay.py record [--data DIR] [--port N]           serve recordings, fetch and store misses
  replay.py crawl  [--data DIR]                      pre-record the data the journey scenario needs
"""
import argparse
import hashlib
import json
import sys
import threading
import time
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

UPSTREAM = "https://apparel-large-catalog.mock.shop/api"
CDN_PREFIX = "https://cdn.shopify.com/"
CART_OPS = {"CartCreate", "CartLinesAdd", "CartLinesUpdate"}
ROOT = Path(__file__).resolve().parent


def canonical(variables):
    return json.dumps(
        {k: v for k, v in (variables or {}).items() if v is not None},
        sort_keys=True,
        separators=(",", ":"),
    )


def image_id(url):
    return hashlib.sha1(url.split("?")[0].encode()).hexdigest()[:20]


def money(amount):
    return {"amount": str(float(amount)), "currencyCode": "USD"}


class Store:
    def __init__(self, data, record):
        self.data = Path(data)
        self.record = record
        self.lock = threading.Lock()
        (self.data / "responses").mkdir(parents=True, exist_ok=True)
        (self.data / "images").mkdir(parents=True, exist_ok=True)
        index = self.data / "images.json"
        self.images = json.loads(index.read_text()) if index.exists() else {}
        self.variants = {}
        for f in (self.data / "responses" / "Product").glob("*.json"):
            self.index_product(json.loads(f.read_text())["response"])
        self.reset()

    def reset(self):
        with self.lock:
            self.carts = {}
            self.stats = {"requests": 0, "bytes": 0, "misses": []}

    def count(self, n_bytes, miss=None):
        with self.lock:
            self.stats["requests"] += 1
            self.stats["bytes"] += n_bytes
            if miss:
                self.stats["misses"].append(miss)

    # GraphQL

    def response_path(self, op, variables):
        key = hashlib.sha1(canonical(variables).encode()).hexdigest()[:20]
        return self.data / "responses" / op / f"{key}.json"

    def graphql(self, body):
        op = body.get("operationName")
        variables = body.get("variables") or {}
        if op in CART_OPS:
            return self.cart(op, variables)
        path = self.response_path(op, variables)
        if path.exists():
            return json.loads(path.read_text())["response"]
        if not self.record:
            return None
        response = fetch_graphql(op, body["query"], variables)
        if "errors" in response:
            return response
        self.save(op, variables, body["query"], response)
        return response

    def save(self, op, variables, query, response):
        response.pop("extensions", None)
        path = self.response_path(op, variables)
        path.parent.mkdir(exist_ok=True)
        path.write_text(
            json.dumps(
                {"operationName": op, "variables": json.loads(canonical(variables)), "query": query, "response": response},
                indent=1,
            )
        )
        with self.lock:
            collect_images(response, self.images)
            (self.data / "images.json").write_text(json.dumps(self.images, indent=1, sort_keys=True))
            if op == "Product":
                self.index_product(response)

    def index_product(self, response):
        product = (response.get("data") or {}).get("product")
        if not product:
            return
        images = product["images"]["nodes"]
        image = images[0] if images else None
        for v in product["variants"]["nodes"]:
            self.variants[v["id"]] = {
                "id": v["id"],
                "title": v["title"],
                "price": float(v["price"]["amount"]),
                "image": image,
                "product": {"handle": product["handle"], "title": product["title"], "featuredImage": image},
            }

    # Cart emulation; carts live until /_reset.

    def cart(self, op, variables):
        with self.lock:
            errors = []
            if op == "CartCreate":
                cart_id = f"gid://shopify/Cart/bench-{len(self.carts) + 1}"
                self.carts[cart_id] = []
            else:
                cart_id = variables.get("cartId")
                if cart_id not in self.carts:
                    return {"data": {camel(op): {"cart": None, "userErrors": [{"field": ["cartId"], "message": "Cart not found"}]}}}
            lines = self.carts[cart_id]
            if op in ("CartCreate", "CartLinesAdd"):
                for line in variables.get("lines") or []:
                    variant = self.variants.get(line["merchandiseId"])
                    if not variant:
                        errors.append({"field": ["lines"], "message": "Merchandise not found"})
                        continue
                    existing = next((l for l in lines if l["variant"]["id"] == variant["id"]), None)
                    if existing:
                        existing["quantity"] += line.get("quantity", 1)
                    else:
                        lines.append({"id": f"gid://shopify/CartLine/{variant['id'].rsplit('/', 1)[-1]}", "variant": variant, "quantity": line.get("quantity", 1)})
            else:
                for update in variables.get("lines") or []:
                    target = next((l for l in lines if l["id"] == update["id"]), None)
                    if not target:
                        errors.append({"field": ["lines"], "message": "Line not found"})
                    elif update["quantity"] <= 0:
                        lines.remove(target)
                    else:
                        target["quantity"] = update["quantity"]
            return {"data": {camel(op): {"cart": render_cart(cart_id, lines), "userErrors": errors}}}

    # Images

    def image(self, ident, width):
        path = self.data / "images" / f"{ident}-w{width or 0}.jpg"
        if path.exists():
            return path.read_bytes()
        url = self.images.get(ident)
        if not self.record or not url:
            return None
        params = {"format": "jpg"}
        if width:
            params["width"] = width
        sep = "&" if "?" in url else "?"
        req = urllib.request.Request(url + sep + urllib.parse.urlencode(params), headers={"Accept": "image/jpeg"})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
        path.write_bytes(data)
        return data


def camel(op):
    return op[0].lower() + op[1:]


def render_cart(cart_id, lines):
    nodes = []
    for l in lines:
        v = l["variant"]
        nodes.append(
            {
                "id": l["id"],
                "quantity": l["quantity"],
                "cost": {"totalAmount": money(v["price"] * l["quantity"])},
                "merchandise": {"id": v["id"], "title": v["title"], "image": v["image"], "product": v["product"]},
            }
        )
    return {
        "id": cart_id,
        "checkoutUrl": "/checkout",
        "totalQuantity": sum(l["quantity"] for l in lines),
        "cost": {"subtotalAmount": money(sum(l["variant"]["price"] * l["quantity"] for l in lines))},
        "lines": {"nodes": nodes},
    }


def collect_images(value, index):
    if isinstance(value, dict):
        for k, v in value.items():
            if k == "url" and isinstance(v, str) and v.startswith(CDN_PREFIX):
                index[image_id(v)] = v
            else:
                collect_images(v, index)
    elif isinstance(value, list):
        for v in value:
            collect_images(v, index)


def rewrite(value, base):
    if isinstance(value, dict):
        out = {}
        for k, v in value.items():
            if k == "url" and isinstance(v, str) and v.startswith(CDN_PREFIX):
                out[k] = f"{base}/img/{image_id(v)}"
            elif k == "checkoutUrl" and isinstance(v, str) and v.startswith("/"):
                out[k] = base + v
            else:
                out[k] = rewrite(v, base)
        return out
    if isinstance(value, list):
        return [rewrite(v, base) for v in value]
    return value


def fetch_graphql(op, query, variables):
    body = json.dumps({"operationName": op, "query": query, "variables": variables}).encode()
    req = urllib.request.Request(UPSTREAM, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


# The Shopify CDN's header; without one, NSURLCache-backed image loaders refetch every image.
IMAGE_CACHE_CONTROL = "public, max-age=60"


def make_handler(store, log):
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def base(self):
            return "http://" + self.headers.get("Host", "localhost")

        def send(self, status, body, content_type, miss=None, headers=()):
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            for name, value in headers:
                self.send_header(name, value)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            store.count(len(body), miss)
            log.write(json.dumps({"t": round(time.time(), 3), "path": self.path, "status": status, "bytes": len(body), "miss": miss}) + "\n")
            log.flush()

        def json(self, status, value, miss=None):
            self.send(status, json.dumps(value).encode(), "application/json", miss)

        def do_POST(self):
            path = urllib.parse.urlparse(self.path).path
            body = self.rfile.read(int(self.headers.get("Content-Length", 0)) or 0)
            if path == "/_reset":
                store.reset()
                return self.json(200, {"ok": True})
            if path != "/api":
                return self.json(404, {"error": "not found"}, miss=self.path)
            try:
                request = json.loads(body)
            except ValueError:
                return self.json(400, {"error": "invalid JSON"})
            op = request.get("operationName")
            if not op:
                return self.json(400, {"error": "operationName is required"}, miss="(no operationName)")
            response = store.graphql(request)
            if response is None:
                return self.json(404, {"errors": [{"message": "No recording"}]}, miss=f"{op} {canonical(request.get('variables'))}")
            self.json(200, rewrite(response, self.base()))

        def do_GET(self):
            url = urllib.parse.urlparse(self.path)
            if url.path == "/_stats":
                return self.json(200, store.stats)
            if url.path == "/checkout":
                return self.send(200, b"<!doctype html><title>Checkout</title><h1>Checkout</h1>", "text/html")
            if url.path.startswith("/img/"):
                width = urllib.parse.parse_qs(url.query).get("width", [None])[0]
                data = store.image(url.path[5:], int(width) if width else None)
                if data is None:
                    return self.json(404, {"error": "no image"}, miss=self.path)
                return self.send(200, data, "image/jpeg", headers=[("Cache-Control", IMAGE_CACHE_CONTROL)])
            self.json(404, {"error": "not found"}, miss=self.path)

        def log_message(self, *args):
            pass

    return Handler


# Crawl: everything the journey in measurement/README.md reaches.

def crawl(store):
    query = (ROOT.parents[1] / "prompt" / "storefront.graphql").read_text()

    def op(name, variables):
        response = store.graphql({"operationName": name, "query": query, "variables": variables})
        if response is None or "errors" in response:
            raise RuntimeError(f"{name} {variables}: {response}")
        return response["data"]

    products = set()
    images = []  # (url, width)

    def cards(nodes):
        for p in nodes:
            products.add(p["handle"])
            if p.get("featuredImage"):
                images.extend([(p["featuredImage"]["url"], 480), (p["featuredImage"]["url"], 240)])

    def pages(name, variables, connection):
        after = None
        while True:
            data = op(name, {**variables, "after": after})
            conn = connection(data)
            cards(conn["nodes"])
            if not conn["pageInfo"]["hasNextPage"]:
                return
            after = conn["pageInfo"]["endCursor"]

    home = op("Home", {})
    cards(home["products"]["nodes"])
    for c in home["collections"]["nodes"]:
        if c.get("image"):
            images.extend([(c["image"]["url"], 480), (c["image"]["url"], 1080)])
    first = home["collections"]["nodes"][0]["handle"]
    for sort_key, reverse in [("COLLECTION_DEFAULT", False), ("BEST_SELLING", False), ("PRICE", False), ("PRICE", True)]:
        pages("CollectionProducts", {"handle": first, "first": 24, "sortKey": sort_key, "reverse": reverse}, lambda d: d["collection"]["products"])
    for n in range(1, len("jacket") + 1):
        pages("Search", {"query": "jacket"[:n], "first": 24}, lambda d: d["search"])
    for handle in sorted(products):
        data = op("Product", {"handle": handle})
        images.extend((i["url"], 1080) for i in data["product"]["images"]["nodes"])
        for r in data["productRecommendations"]:
            if r.get("featuredImage"):
                images.append((r["featuredImage"]["url"], 480))
        rec = data["productRecommendations"][:1]
        if rec:
            rec_data = op("Product", {"handle": rec[0]["handle"]})
            images.extend((i["url"], 1080) for i in rec_data["product"]["images"]["nodes"])
    for url, width in sorted(set(images)):
        store.image(image_id(url), width)
    print(f"crawled {len(products)} products, {len(set(images))} images", file=sys.stderr)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("mode", choices=["serve", "record", "crawl"])
    p.add_argument("--data", default=str(ROOT / "data"))
    p.add_argument("--port", type=int, default=8787)
    p.add_argument("--log", default="-")
    a = p.parse_args()
    store = Store(a.data, record=a.mode != "serve")
    if a.mode == "crawl":
        return crawl(store)
    log = sys.stdout if a.log == "-" else open(a.log, "a")
    server = ThreadingHTTPServer(("0.0.0.0", a.port), make_handler(store, log))
    print(f"{a.mode}: http://0.0.0.0:{a.port}/api (data: {a.data})", file=sys.stderr)
    server.serve_forever()


if __name__ == "__main__":
    main()
