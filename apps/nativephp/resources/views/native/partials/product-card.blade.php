{{-- Grid product card (Home best sellers, Collection grid). Expects $p, $ref, optional $press. --}}
@php $press ??= "openProduct('".$p['handle']."')"; @endphp
<native:pressable
    ref="{{ $ref }}"
    @press="{{ $press }}"
    class="flex-1 gap-2"
>
    <native:image :src="$p['image'] ?? ''" fit="cover" class="w-full aspect-[0.75] rounded-[8] bg-theme-surface" />
    <native:text class="text-[14] leading-[18px] text-theme-text" :max-lines="2">{{ $p['title'] }}</native:text>
    @include('native.partials.price', ['p' => $p])
</native:pressable>
