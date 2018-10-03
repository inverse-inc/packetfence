<template>
    <b-button variant="primary" type="submit" v-bind="$attrs"><icon name="circle-notch" spin v-show="isLoading"></icon> <slot>{{ $t('Save') }}</slot></b-button>
</template>

<script>
export default {
  name: 'pf-button-save',
  props: {
    isLoading: {
      type: Boolean,
      default: false
    }
  }
}
</script>
