<?php

/**
 * Native UI — Theme Tokens
 *
 * Published via `php artisan vendor:publish --tag=native-ui-config`.
 * Edit to customize your app's visual identity in one place.
 *
 * For dynamic per-tenant theming, use Native\Mobile\UI\Theme::merge([...])
 * from a service provider. Runtime merges deep-merge on top of these values.
 *
 * Decision log: /docs/NATIVE-UI-REWRITE-PLAN.md (D — theme layer)
 */

return [

    /*
    |---------------------------------------------------------------------------
    | Theme
    |---------------------------------------------------------------------------
    |
    | Color tokens (open-ended map), 4 radii, 4 font sizes, font family.
    |
    | "on-X" means "color of content placed ON a surface of color X"
    |   — i.e., text/icons on that background.
    |
    | The token map is OPEN-ENDED: add any key your design needs (e.g. a
    | `warning` pair) to both blocks and `bg-theme-warning` /
    | `text-theme-on-warning` / `border-theme-warning` resolve immediately.
    | Theme classes also accept opacity modifiers — `bg-theme-primary/15`
    | is the tonal-fill idiom (the alpha applies to the dark companion
    | too). In PHP (layout chrome builders, dynamic styling) read tokens
    | with the appearance-aware `theme()` helper: `theme('primary')`.
    |
    | Color tokens accept:
    |   - CSS hex: '#B91C1C', '#F00', or with alpha '#8B5CF680' (#RRGGBBAA)
    |   - Tailwind palette names: 'red-300', 'orange-800'
    |   - Opacity modifiers on either: 'red-300/20', '#8B5CF6/50'
    |
    | Dark mode is auto-derived from `light` when `dark` is not set. To opt
    | into explicit dark tokens, fill out the `dark` block.
    |
    | The default pairs meet WCAG AA (4.5:1) — if you customize, keep each
    | `on-*` color at 4.5:1 contrast against its background token.
    |
    */

    'theme' => [

        // Everbloom design tokens (spec/design/screens/Tokens.dc.html).
        // Light only: the app does not support dark mode, so the dark block
        // repeats the light values and config('nativephp.appearance') pins
        // the interface style to light.
        'light' => [
            'background' => '#FFFFFF',
            'on-background' => '#1C1B19',
            'surface' => '#F4F1EC',
            'on-surface' => '#1C1B19',
            'surface-variant' => '#F4F1EC',
            'on-surface-variant' => '#6E6A63',
            'skeleton' => '#EDE9E3',
            'border' => '#E6E1D9',
            'outline' => '#E6E1D9',
            'outline-variant' => '#E6E1D9',
            'text' => '#1C1B19',
            'text-muted' => '#6E6A63',
            'body' => '#3D3A35',
            'sale' => '#B4361E',
            'on-sale' => '#FFFFFF',
            'primary' => '#1C1B19',
            'on-primary' => '#FFFFFF',
            'secondary' => '#6E6A63',
            'on-secondary' => '#FFFFFF',
            'destructive' => '#B4361E',
            'on-destructive' => '#FFFFFF',
            'accent' => '#1C1B19',
            'on-accent' => '#FFFFFF',
            'white' => '#FFFFFF',
        ],

        'dark' => [
            'background' => '#FFFFFF',
            'on-background' => '#1C1B19',
            'surface' => '#F4F1EC',
            'on-surface' => '#1C1B19',
            'surface-variant' => '#F4F1EC',
            'on-surface-variant' => '#6E6A63',
            'skeleton' => '#EDE9E3',
            'border' => '#E6E1D9',
            'outline' => '#E6E1D9',
            'outline-variant' => '#E6E1D9',
            'text' => '#1C1B19',
            'text-muted' => '#6E6A63',
            'body' => '#3D3A35',
            'sale' => '#B4361E',
            'on-sale' => '#FFFFFF',
            'primary' => '#1C1B19',
            'on-primary' => '#FFFFFF',
            'secondary' => '#6E6A63',
            'on-secondary' => '#FFFFFF',
            'destructive' => '#B4361E',
            'on-destructive' => '#FFFFFF',
            'accent' => '#1C1B19',
            'on-accent' => '#FFFFFF',
            'white' => '#FFFFFF',
        ],

        // Corner radii (points / dp): image / button / chip.
        'radius-sm' => 8,
        'radius-md' => 12,
        'radius-lg' => 12,
        'radius-full' => 9999,

        // Font size scale (points / sp).
        'font-sm' => 13,
        'font-md' => 15,
        'font-lg' => 17,
        'font-xl' => 22,

    ],

    /*
    |---------------------------------------------------------------------------
    | Fonts
    |---------------------------------------------------------------------------
    |
    | Semantic names for bundled fonts (resources/fonts/ file tokens, minus
    | the extension). Use an alias anywhere a font token works — the `font`
    | attribute (`font="accent"`), chrome ->font() builders, or the layout
    | $font property. The `default` alias is the app-wide default font:
    | 'System' resolves to the platform face (San Francisco on iOS, Roboto
    | on Android); set a bundled token to apply it everywhere. Download one
    | with `php artisan native:font Inter --default`. Per-element `font`
    | attributes and font-serif / font-mono classes still win over the default.
    |
    | Weights: a family's `-Regular` token (or its bare family name, e.g.
    | 'Inter') follows the font-medium / font-semibold / font-bold classes by
    | drawing the sibling file bundled for that weight — Inter-Medium,
    | Inter-SemiBold, Inter-Bold — the names `native:font` downloads. A missing
    | weight uses the nearest bundled one; a variable font moves along its
    | weight axis instead. Any other face ('Inter-Bold') is drawn as named.
    |
    |   'fonts' => [
    |       'default' => 'Inter-Regular',
    |       'accent'  => 'DynaPuff-Regular',
    |   ],
    |
    */

    'fonts' => [
        'default' => 'System',
    ],

];
