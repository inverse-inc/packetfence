<template>
  <div class="base-label col-form-label text-nowrap mr-2"
       :class="{ 'text-black-50': isLocked }">
    <slot/>
  </div>
</template>

<script>
export const useLabelProps = {
  label: {
    default: null,
    type: String
  },
  isLocked: {
    default: false,
    type: Boolean
  },
}

const props = {
  ...useLabelProps,
}

export default {
  name: 'base-label',
  inheritAttrs: false,
  props,
}
</script>


<style scoped lang="scss">

div.base-label {
  font-size: $font-size-sm;
  font-weight: 500;
  line-height: $font-size-base / $font-size-sm * $line-height-base;
  user-select: none;
  padding: 0;

  &:not(.is-disabled) {
    cursor: pointer;
  }
}

</style>
