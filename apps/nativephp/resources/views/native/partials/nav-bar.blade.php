{{-- 44pt navigation bar: back button + centered title. Expects $title. --}}
<native:row class="w-full h-[44] px-2 items-center">
    <native:pressable ref="back" @press="goBack" a11y-label="Back" class="w-[44] h-[44] items-center justify-center">
        <native:icon name="custom:back" :size="24" class="text-theme-text" />
    </native:pressable>
    <native:text class="flex-1 text-[17] font-semibold text-center text-theme-text" :max-lines="1">{{ $title }}</native:text>
    <native:column class="w-[44] h-[44]" />
</native:row>
