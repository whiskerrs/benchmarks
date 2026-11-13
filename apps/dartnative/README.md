# Everbloom (DartNative)

A small shopping app for iOS and Android built with
[DartNative](https://github.com/DartNative/dartnative), reading the Shopify
Storefront API served by mock.shop. The specification is in `spec/`.

- `BUILD.md`: how to install, build and launch it on each platform.
- `NOTES.md`: decisions, dependencies, and what could not be verified
  (DartNative needs a licence key for the app to run).

Code map:

- `lib/main.dart` boots the app; `lib/shell.dart` is the tab shell with one
  stack of screens per tab.
- `lib/screens/` Home, Collection, Product, Search, Cart.
- `lib/api/` the GraphQL documents (verbatim from the spec), the HTTP client
  and the response models.
- `lib/state/` navigation and cart state.
- `lib/ui/` design tokens, vector icons, shared widgets.
- `lib/native/` FFI bridges for NSLog and accessibility identifiers.
