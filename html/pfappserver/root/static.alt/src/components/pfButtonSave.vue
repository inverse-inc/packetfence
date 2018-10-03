<template>
    <b-button :style="{ minWidth: btnWidth }" ref="saveButton" variant="primary" type="submit" v-bind="$attrs">
        <icon name="circle-notch" spin v-if="isLoading"></icon>
        <slot v-else>{{ $t('Save') }}</slot></b-button>
</template>

<script>
export default {
  name: 'pf-button-save',
  props: {
    isLoading: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      btnWidth: 0
    }
  },
  mounted () {
    this.btnWidth = (this.$refs.saveButton.clientWidth + 2) + 'px'
  }
}
</script>
