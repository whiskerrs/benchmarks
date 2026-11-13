{{-- Cart (spec/design/screens/Cart.dc.html, empty state from States.dc.html) --}}
@php $lines = $cart['lines'] ?? []; @endphp
<native:column class="w-full flex-1 safe-area-top bg-theme-background">
    <native:row class="w-full h-[44] px-4 items-center">
        <native:text class="text-[22] font-bold text-theme-text">Cart</native:text>
    </native:row>

    @if ($lines === [])
        <native:column class="w-full flex-1 items-center justify-center gap-3 px-8">
            <native:text class="text-[17] font-bold text-theme-text text-center">Your cart is empty</native:text>
            <native:text class="text-[15] leading-[22px] text-theme-text-muted text-center">Items you add will appear here.</native:text>
        </native:column>
    @else
        <native:scroll-view :shows-indicators="false" class="w-full flex-1">
            <native:column class="w-full px-4">
                @foreach ($lines as $i => $line)
                    <native:row :native:key="'l-'.$line['id']" ref="cart-line-{{ $i }}" class="w-full py-4 gap-3 border-b border-theme-border">
                        <native:image :src="$line['image'] ?? ''" fit="cover" class="w-[80] h-[107] rounded-[8] bg-theme-surface" />
                        <native:column class="flex-1 h-[107] gap-1">
                            <native:text class="text-[15] leading-[20px] font-semibold text-theme-text" :max-lines="2">{{ $line['title'] }}</native:text>
                            @if ($line['variant'] !== '')
                                <native:text class="text-[13] text-theme-text-muted" :max-lines="1">{{ $line['variant'] }}</native:text>
                            @endif
                            <native:column class="flex-1" />
                            <native:row class="w-full items-center justify-between">
                                <native:row class="h-[36] rounded-[12] border border-theme-border items-center {{ $cartBusy ? 'opacity-50' : '' }}">
                                    <native:pressable ref="qty-dec-{{ $i }}" @press="changeQuantity({{ $i }}, -1)" a11y-label="Decrease quantity" class="w-[36] h-[34] items-center justify-center">
                                        <native:icon name="custom:minus" :size="16" class="text-theme-text" />
                                    </native:pressable>
                                    <native:text class="min-w-[24] text-[15] font-semibold text-center text-theme-text">{{ $line['quantity'] }}</native:text>
                                    <native:pressable ref="qty-inc-{{ $i }}" @press="changeQuantity({{ $i }}, 1)" a11y-label="Increase quantity" class="w-[36] h-[34] items-center justify-center">
                                        <native:icon name="custom:plus" :size="16" class="text-theme-text" />
                                    </native:pressable>
                                </native:row>
                                <native:text class="text-[15] font-bold text-theme-text">{{ $line['total'] }}</native:text>
                            </native:row>
                        </native:column>
                    </native:row>
                @endforeach
            </native:column>
        </native:scroll-view>

        <native:column class="w-full p-4 gap-3 bg-theme-background border-t border-theme-border">
            <native:row class="w-full items-end justify-between">
                <native:text class="text-[15] text-theme-text">Subtotal</native:text>
                <native:column ref="cart-subtotal" a11y-label="{{ $cart['subtotal'] }}">
                    <native:text class="text-[17] font-bold text-theme-text">{{ $cart['subtotal'] }}</native:text>
                </native:column>
            </native:row>
            <native:text class="text-[13] text-theme-text-muted">Taxes and shipping are calculated at checkout.</native:text>
            <native:pressable ref="checkout" @press="checkout" class="w-full h-[52] rounded-[12] bg-theme-text items-center justify-center">
                <native:text class="text-[16] font-semibold text-white">Check out</native:text>
            </native:pressable>
        </native:column>
    @endif
</native:column>
