<template>
  <b-button :style="{ minWidth: btnWidth }" ref="saveButton" variant="primary" type="submit" v-bind="$attrs">
    <icon name="circle-notch" spin v-if="isLoading"></icon>
    <template v-else>
      <icon :name="icon" v-if="icon" class="mr-2"></icon>
      <slot>{{ $t('Save') }}</slot>
    </template>
  </b-button>
</template>

<script>
export default {
  name: 'pf-button-save',
  props: {
    isLoading: {
      type: Boolean,
      default: false
    },
    icon: {
      type: String
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
