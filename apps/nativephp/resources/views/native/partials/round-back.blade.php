{{-- Round back button over the product image's top-left corner. --}}
@if ($inline ?? false)
    <native:pressable ref="back" @press="goBack" a11y-label="Back" class="w-[40] h-[40] rounded-full bg-theme-background items-center justify-center">
        <native:icon name="custom:back" :size="24" class="text-theme-text" />
    </native:pressable>
@else
    <native:column class="w-full h-full items-start pl-[12] safe-area-top">
        <native:pressable ref="back" @press="goBack" a11y-label="Back" class="w-[40] h-[40] rounded-full bg-theme-background items-center justify-center">
            <native:icon name="custom:back" :size="24" class="text-theme-text" />
        </native:pressable>
    </native:column>
@endif
