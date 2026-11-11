# Design

Reference design for the benchmark shop app, exported from a Claude Design canvas.

- Source canvas: https://claude.ai/artifact/BX2jxHEGYBfdsLBXscdvEr
- Data source: `https://apparel-large-catalog.mock.shop/api` (Shopify Storefront API, no token)

## Files

| File | Screen |
|---|---|
| `screens/Main.dc.html` | Home (full scroll height; tab bar fixed to the viewport bottom) |
| `screens/Collection.dc.html` | Collection product grid with sort |
| `screens/Product.dc.html` | Product detail (full scroll height; Add to cart bar fixed to the viewport bottom) |
| `screens/Search.dc.html` | Search |
| `screens/Cart.dc.html` | Cart |
| `screens/States.dc.html` | Loading skeleton / empty cart / load error |
| `screens/Tokens.dc.html` | Colors, type scale, spacing, components |
| `screens/canvas.json` | Canvas layout (frame sizes) |
| `img/` | Sample product images used in the mockups |

## Reading the screens

Each screen is HTML with inline CSS. Phone frame is 390×844 pt; the top 54 pt and bottom 34 pt are the device safe areas.

Template syntax: `<sc-for list="{{items}}" as="item">` repeats its children, `<sc-if value="{{cond}}">` renders conditionally, and `{{name}}` is filled from `renderVals()` in the `<script type="text/x-dc">` block at the bottom of each file. `<a href="X.dc.html">` marks navigation to screen X.

Product names, prices and images in the mockups are sample data; the app loads them from the API. Images in `img/` are visual reference only.
