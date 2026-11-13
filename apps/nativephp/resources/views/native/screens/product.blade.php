{{-- Product (spec/design/screens/Product.dc.html). The tab bar is hidden here. --}}
@php
    $product = $screen['product'];
    $variant = $product['variants'][$screen['variant']] ?? null;
@endphp
<native:column class="w-full flex-1 bg-theme-background">
    @if ($screen['status'] === 'loaded')
        <native:scroll-view :shows-indicators="false" class="w-full flex-1">
            <native:column class="w-full pb-8">
                {{-- Image carousel (3:4), swiped horizontally, with page dots --}}
                <native:stack class="w-full aspect-[0.75] bg-theme-surface">
                    <native:pager
                        ref="product-carousel"
                        horizontal
                        report-on-settle
                        :page="$screen['image']"
                        on-page-change="showImage('{{ $id }}')"
                        a11y-label="Product images"
                        class="w-full h-full bg-theme-surface"
                    >
                        @foreach ($product['images'] as $i => $src)
                            <native:column :native:key="'img-'.$i" class="w-full h-full bg-theme-surface">
                                <native:image :src="$src ?? ''" fit="cover" class="w-full h-full" />
                            </native:column>
                        @endforeach
                    </native:pager>
                    @if (count($product['images']) > 1)
                        <native:column class="w-full h-full justify-end items-center pb-[12]">
                        <native:row class="gap-1">
                            @foreach ($product['images'] as $i => $src)
                                <native:column class="w-[24] h-[24] items-center justify-center">
                                    <native:column class="w-[8] h-[8] rounded-full {{ $i === $screen['image'] ? 'bg-theme-text' : 'bg-theme-text/25' }}" />
                                </native:column>
                            @endforeach
                        </native:row>
                        </native:column>
                    @endif
                    @include('native.partials.round-back')
                </native:stack>

                {{-- Title and price --}}
                <native:column class="w-full px-4 pt-5 gap-[6]">
                    <native:text class="text-[22] leading-[28px] font-bold text-theme-text">{{ $product['title'] }}</native:text>
                    @if ($variant)
                        @if ($variant['compare'])
                            <native:row class="gap-2 items-end">
                                <native:text class="text-[20] font-bold text-theme-sale">{{ $variant['price'] }}</native:text>
                                <native:text class="text-[15] text-theme-text-muted line-through">{{ $variant['compare'] }}</native:text>
                            </native:row>
                        @else
                            <native:text class="text-[20] font-bold text-theme-text">{{ $variant['price'] }}</native:text>
                        @endif
                    @endif
                </native:column>

                {{-- Options --}}
                @foreach ($product['options'] as $o => $option)
                    <native:column class="w-full px-4 pt-6 gap-3">
                        <native:row class="w-full gap-1">
                            <native:text class="text-[15] font-semibold text-theme-text">{{ $option['name'] }}:</native:text>
                            <native:text class="text-[15] text-theme-text-muted">{{ $variant['options'][$option['name']] ?? '' }}</native:text>
                        </native:row>
                        <native:row class="w-full gap-2 flex-wrap">
                            @foreach ($option['values'] as $v => $value)
                                @php $picked = ($variant['options'][$option['name']] ?? null) === $value; @endphp
                                <native:pressable
                                    ref="option-{{ $option['name'] }}-{{ $value }}"
                                    @press="selectOption('{{ $id }}', {{ $o }}, {{ $v }})"
                                    class="min-w-[56] h-[44] px-4 rounded-[12] items-center justify-center bg-theme-background {{ $picked ? 'border-2 border-theme-text' : 'border border-theme-border' }}"
                                >
                                    <native:text class="text-[15] text-theme-text {{ $picked ? 'font-semibold' : 'font-normal' }}" :max-lines="1">{{ $value }}</native:text>
                                </native:pressable>
                            @endforeach
                        </native:row>
                    </native:column>
                @endforeach

                {{-- Description --}}
                <native:column class="w-full px-4 pt-6 gap-2">
                    <native:text class="text-[15] font-semibold text-theme-text">Description</native:text>
                    <native:text class="text-[15] leading-[22px] text-theme-body">{{ $product['description'] }}</native:text>
                </native:column>

                {{-- You may also like --}}
                @if ($screen['recs'] !== [])
                    <native:column class="w-full pt-8">
                        <native:text class="px-4 pb-3 text-[17] font-bold text-theme-text">You may also like</native:text>
                        <native:scroll-view horizontal :shows-indicators="false" class="w-full">
                            <native:row class="gap-3 px-4 items-start">
                                @foreach ($screen['recs'] as $i => $p)
                                    <native:pressable
                                        ref="recommendation-{{ $i }}"
                                        @press="openProduct('{{ $p['handle'] }}')"
                                        class="w-[140] gap-[6]"
                                    >
                                        <native:image :src="$p['image'] ?? ''" fit="cover" class="w-[140] h-[187] rounded-[8] bg-theme-surface" />
                                        <native:text class="w-[140] text-[14] leading-[18px] text-theme-text" :max-lines="2">{{ $p['title'] }}</native:text>
                                        <native:text class="text-[14] font-bold text-theme-text">{{ $p['price'] }}</native:text>
                                    </native:pressable>
                                @endforeach
                            </native:row>
                        </native:scroll-view>
                    </native:column>
                @endif
            </native:column>
        </native:scroll-view>

        {{-- Add to cart bar, fixed to the bottom --}}
        @if ($variant)
            @php $busy = $screen['adding'] || $cartBusy; @endphp
            <native:column class="w-full px-4 pt-3 bg-theme-background border-t border-theme-border safe-area-bottom">
                <native:pressable
                    ref="add-to-cart"
                    @press="addToCart('{{ $id }}')"
                    class="w-full h-[52] mb-3 rounded-[12] bg-theme-text items-center justify-center {{ $busy ? 'opacity-50' : '' }}"
                >
                    <native:text class="text-[16] font-semibold text-white">Add to cart · {{ $variant['price'] }}</native:text>
                </native:pressable>
            </native:column>
        @endif
    @else
        <native:column class="w-full flex-1 safe-area-top">
            <native:row class="w-full h-[52] px-3 items-center">
                @include('native.partials.round-back', ['inline' => true])
            </native:row>
            @if ($screen['status'] === 'error')
                @include('native.partials.error', ['retry' => "retryProduct('{$id}')"])
            @else
                @include('native.partials.spinner')
            @endif
        </native:column>
    @endif
</native:column>
