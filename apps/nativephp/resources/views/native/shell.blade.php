<native:column class="w-full h-full bg-theme-background">
    @switch($screen['type'])
        @case('home')
            @include('native.screens.home')
            @break
        @case('collection')
            @include('native.screens.collection')
            @break
        @case('product')
            @include('native.screens.product')
            @break
        @case('search')
            @include('native.screens.search')
            @break
        @case('cart')
            @include('native.screens.cart')
            @break
    @endswitch

    @if ($screen['type'] !== 'product')
        @include('native.partials.tab-bar')
    @endif
</native:column>
