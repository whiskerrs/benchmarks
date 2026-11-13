{{-- Home (spec/design/screens/Main.dc.html) --}}
<native:column class="w-full flex-1 safe-area-top bg-theme-background">
    @if ($screen['status'] === 'loaded')
        <native:scroll-view ref="home-scroll" :shows-indicators="false" class="w-full flex-1">
            <native:column class="w-full pb-6">
                @include('native.partials.wordmark')

                {{-- Collection chips --}}
                <native:scroll-view horizontal :shows-indicators="false" class="w-full">
                    <native:row class="gap-2 px-4 pt-2 pb-3">
                        @foreach ($screen['collections'] as $i => $c)
                            <native:pressable
                                ref="collection-chip-{{ $i }}"
                                @press="openCollection('{{ $c['handle'] }}')"
                                class="h-[36] px-[14] rounded-full bg-theme-surface items-center justify-center"
                            >
                                <native:text class="text-[14] font-medium text-theme-text" :max-lines="1">{{ $c['title'] }}</native:text>
                            </native:pressable>
                        @endforeach
                    </native:row>
                </native:scroll-view>

                {{-- Featured collection: the first collection --}}
                @if ($featured = $screen['collections'][0] ?? null)
                    <native:pressable
                        ref="featured-collection"
                        @press="openCollection('{{ $featured['handle'] }}')"
                        class="mx-4 mt-1 h-[240] rounded-[12] bg-theme-surface"
                    >
                        <native:stack class="w-full h-full rounded-[12]">
                            <native:image :src="$featured['banner'] ?? ''" fit="cover" class="w-full h-full rounded-[12]" />
                            <native:column class="w-full h-full justify-end">
                                <native:column class="w-full p-4 gap-[2] bg-theme-text/72 rounded-b-[12]">
                                    <native:text :letter-spacing="0.05" class="text-[12] font-semibold uppercase text-white">Featured collection</native:text>
                                    <native:text class="text-[20] font-bold text-white" :max-lines="2">{{ $featured['title'] }}</native:text>
                                    <native:text class="text-[14] text-white">Shop now</native:text>
                                </native:column>
                            </native:column>
                        </native:stack>
                    </native:pressable>
                @endif

                {{-- Collections carousel --}}
                <native:column class="w-full pt-7">
                    <native:text class="px-4 pb-3 text-[17] font-bold text-theme-text">Collections</native:text>
                    <native:scroll-view horizontal :shows-indicators="false" class="w-full">
                        <native:row class="gap-3 px-4 items-start">
                            @foreach ($screen['collections'] as $i => $c)
                                <native:pressable
                                    ref="collection-card-{{ $i }}"
                                    @press="openCollection('{{ $c['handle'] }}')"
                                    class="w-[140] gap-2"
                                >
                                    <native:image :src="$c['image'] ?? ''" fit="cover" class="w-[140] h-[175] rounded-[8] bg-theme-surface" />
                                    <native:text class="w-[140] text-[14] font-semibold leading-[18px] text-theme-text" :max-lines="2">{{ $c['title'] }}</native:text>
                                </native:pressable>
                            @endforeach
                        </native:row>
                    </native:scroll-view>
                </native:column>

                {{-- Best sellers --}}
                <native:column class="w-full pt-7 px-4">
                    <native:text class="pb-3 text-[17] font-bold text-theme-text">Best sellers</native:text>
                    <native:column class="w-full gap-5">
                        @foreach (array_chunk($screen['products'], 2, true) as $pair)
                            <native:row class="w-full gap-3 items-start">
                                @foreach ($pair as $i => $p)
                                    @include('native.partials.product-card', ['p' => $p, 'ref' => 'best-seller-'.$i])
                                @endforeach
                                @if (count($pair) === 1)
                                    <native:column class="flex-1" />
                                @endif
                            </native:row>
                        @endforeach
                    </native:column>
                </native:column>
            </native:column>
        </native:scroll-view>
    @else
        @include('native.partials.wordmark')
        @if ($screen['status'] === 'error')
            @include('native.partials.error', ['retry' => 'loadHome'])
        @else
            {{-- Skeleton (States.dc.html, "Home loading") --}}
            <native:column class="w-full flex-1">
                <native:row class="gap-2 px-4 pt-2 pb-3">
                    <native:column class="w-[52] h-[36] rounded-full bg-theme-skeleton" />
                    <native:column class="w-[110] h-[36] rounded-full bg-theme-skeleton" />
                    <native:column class="w-[96] h-[36] rounded-full bg-theme-skeleton" />
                    <native:column class="w-[80] h-[36] rounded-full bg-theme-skeleton" />
                </native:row>
                <native:column class="mx-4 mt-1 h-[240] rounded-[12] bg-theme-skeleton" />
                <native:column class="px-4 pt-7 pb-3">
                    <native:column class="w-[120] h-[18] rounded-[4] bg-theme-skeleton" />
                </native:column>
                <native:row class="gap-3 px-4">
                    <native:column class="w-[140] h-[175] flex-shrink-0 rounded-[8] bg-theme-skeleton" />
                    <native:column class="w-[140] h-[175] flex-shrink-0 rounded-[8] bg-theme-skeleton" />
                    <native:column class="w-[140] h-[175] flex-shrink-0 rounded-[8] bg-theme-skeleton" />
                </native:row>
            </native:column>
        @endif
    @endif
</native:column>
