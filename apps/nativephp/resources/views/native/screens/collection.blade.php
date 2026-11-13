{{-- Collection (spec/design/screens/Collection.dc.html) --}}
@php
    $sorts = [
        'featured' => 'Featured',
        'best-selling' => 'Best selling',
        'price-asc' => 'Price: low to high',
        'price-desc' => 'Price: high to low',
    ];
@endphp
<native:column class="w-full flex-1 safe-area-top bg-theme-background">
    @include('native.partials.nav-bar', ['title' => $screen['title']])

    @if ($screen['description'] !== '')
        <native:text class="px-4 pt-1 text-[14] leading-[20px] text-theme-text-muted">{{ $screen['description'] }}</native:text>
    @endif

    <native:scroll-view horizontal :shows-indicators="false" class="w-full">
        <native:row class="gap-2 px-4 py-3">
            @foreach ($sorts as $key => $label)
                @php $selected = $screen['sort'] === $key; @endphp
                <native:pressable
                    ref="sort-{{ $key }}"
                    @press="setSort('{{ $id }}', '{{ $key }}')"
                    class="h-[32] px-3 rounded-full border items-center justify-center {{ $selected ? 'bg-theme-text border-theme-text' : 'bg-theme-background border-theme-border' }}"
                >
                    <native:text class="text-[13] {{ $selected ? 'font-semibold text-white' : 'font-medium text-theme-text' }}" :max-lines="1">{{ $label }}</native:text>
                </native:pressable>
            @endforeach
        </native:row>
    </native:scroll-view>

    @if ($screen['status'] === 'error')
        @include('native.partials.error', ['retry' => "retryCollection('{$id}')"])
    @elseif ($screen['status'] === 'loading')
        @include('native.partials.spinner')
    @else
        {{-- Lazily rendered 2-column grid: a virtualized list whose rows hold two cards. --}}
        <native:list
            ref="product-grid"
            :shows-indicators="false"
            on-end-reached="loadMoreProducts('{{ $id }}')"
            :end-reached-buffer="3"
            :auto-scroll-to="$screen['anchor'] ?? -1"
            class="w-full flex-1"
        >
            @foreach (array_chunk($screen['products'], 2, true) as $r => $pair)
                <native:row :native:key="'r-'.array_key_first($pair)" class="w-full px-4 pb-5 gap-3 items-start">
                    @foreach ($pair as $i => $p)
                        @include('native.partials.product-card', ['p' => $p, 'ref' => 'product-card-'.$i, 'press' => "openProduct('{$p['handle']}', {$r})"])
                    @endforeach
                    @if (count($pair) === 1)
                        <native:column class="flex-1" />
                    @endif
                </native:row>
            @endforeach
            @if ($screen['loadingMore'])
                <native:row native:key="loading-more" class="w-full py-4 justify-center">
                    <native:activity-indicator />
                </native:row>
            @endif
        </native:list>
    @endif
</native:column>
