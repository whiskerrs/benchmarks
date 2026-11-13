{{-- Search (spec/design/screens/Search.dc.html) --}}
<native:column class="w-full flex-1 safe-area-top bg-theme-background">
    <native:column class="w-full px-4 pt-1 pb-3">
        <native:row class="w-full h-[44] px-3 rounded-[12] bg-theme-surface items-center">
            <native:bare-text-input
                ref="search-input"
                placeholder="Search products"
                native:model.debounce.300ms="searchQuery"
                autocapitalize="none"
                class="flex-1 text-[16] text-theme-text"
            />
        </native:row>
    </native:column>

    @if ($screen['status'] === 'idle')
        <native:column class="w-full px-8 py-12">
            <native:text class="text-[15] leading-[22px] text-theme-text-muted text-center">Search across 995 products by name.</native:text>
        </native:column>
    @elseif ($screen['status'] === 'loading')
        @include('native.partials.spinner')
    @elseif ($screen['status'] === 'error')
        @include('native.partials.error', ['retry' => 'retrySearch'])
    @else
        <native:text class="px-4 pt-1 pb-2 text-[13] text-theme-text-muted">{{ $screen['total'] }} results</native:text>
        <native:list
            ref="search-results"
            :shows-indicators="false"
            on-end-reached="loadMoreResults"
            :end-reached-buffer="6"
            :auto-scroll-to="$screen['anchor'] ?? -1"
            class="w-full flex-1"
        >
            @foreach ($screen['results'] as $i => $p)
                <native:pressable
                    :native:key="'s-'.$i"
                    ref="search-result-{{ $i }}"
                    @press="openProduct('{{ $p['handle'] }}', {{ $i }})"
                    class="w-full px-4 py-2"
                >
                    <native:row class="w-full gap-3 items-center">
                        <native:image :src="$p['thumb'] ?? ''" fit="cover" class="w-[64] h-[85] rounded-[8] bg-theme-surface" />
                        <native:column class="flex-1 gap-1">
                            <native:text class="text-[15] leading-[20px] text-theme-text">{{ $p['title'] }}</native:text>
                            <native:text class="text-[15] font-bold text-theme-text">{{ $p['price'] }}</native:text>
                        </native:column>
                    </native:row>
                </native:pressable>
            @endforeach
            @if ($screen['loadingMore'])
                <native:row native:key="loading-more" class="w-full py-4 justify-center">
                    <native:activity-indicator />
                </native:row>
            @endif
        </native:list>
    @endif
</native:column>
