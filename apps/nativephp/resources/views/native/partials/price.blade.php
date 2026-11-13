{{-- Card price: sale price + struck compare-at price when on sale. Expects $p. --}}
@if ($p['compare'])
    <native:row class="gap-[6] items-end">
        <native:text class="text-[15] font-bold text-theme-sale">{{ $p['price'] }}</native:text>
        <native:text class="text-[13] text-theme-text-muted line-through">{{ $p['compare'] }}</native:text>
    </native:row>
@else
    <native:text class="text-[15] font-bold text-theme-text">{{ $p['price'] }}</native:text>
@endif
