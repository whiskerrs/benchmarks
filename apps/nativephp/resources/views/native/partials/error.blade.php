{{-- Load error state. Expects $retry (handler expression). --}}
<native:column class="w-full flex-1 items-center justify-center gap-3 px-8">
    <native:text class="text-[17] font-bold text-theme-text text-center">Couldn’t load products</native:text>
    <native:text class="text-[15] leading-[22px] text-theme-text-muted text-center">Check your connection and try again.</native:text>
    <native:pressable
        ref="error-retry"
        @press="{{ $retry }}"
        class="mt-2 h-[48] px-6 rounded-[12] border border-theme-text bg-theme-background items-center justify-center"
    >
        <native:text class="text-[16] font-semibold text-theme-text">Retry</native:text>
    </native:pressable>
</native:column>
