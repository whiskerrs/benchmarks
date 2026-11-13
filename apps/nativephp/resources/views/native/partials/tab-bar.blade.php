@php
    $tabs = [
        ['id' => 'home', 'label' => 'Home', 'icon' => 'custom:home'],
        ['id' => 'search', 'label' => 'Search', 'icon' => 'custom:search'],
        ['id' => 'cart', 'label' => 'Cart', 'icon' => 'custom:cart'],
    ];
@endphp
<native:column class="w-full bg-theme-background border-t border-theme-border safe-area-bottom">
    <native:row class="w-full h-[49]">
        @foreach ($tabs as $item)
            @php $active = $tab === $item['id']; @endphp
            <native:stack class="flex-1 h-full">
                <native:pressable
                    ref="tab-{{ $item['id'] }}"
                    @press="selectTab('{{ $item['id'] }}')"
                    class="w-full h-full items-center justify-center gap-[2]"
                >
                    <native:icon :name="$item['icon']" :size="24" class="{{ $active ? 'text-theme-text' : 'text-theme-text-muted' }}" />
                    <native:text class="text-[11] {{ $active ? 'font-semibold text-theme-text' : 'font-medium text-theme-text-muted' }}">{{ $item['label'] }}</native:text>
                </native:pressable>
                @if ($item['id'] === 'cart' && $cartCount > 0)
                    {{-- Badge layer: outside the tab button so it stays its own accessibility element. --}}
                    <native:row class="w-full h-full pt-[4]">
                        <native:column class="flex-1" />
                        <native:column class="flex-1 items-start pl-[6]">
                            <native:column ref="cart-badge" a11y-label="{{ $cartCount }}" class="min-w-[18] h-[18] px-[5] rounded-full bg-theme-sale items-center justify-center">
                                <native:text class="text-[11] font-bold text-white">{{ $cartCount }}</native:text>
                            </native:column>
                        </native:column>
                    </native:row>
                @endif
            </native:stack>
        @endforeach
    </native:row>
</native:column>
