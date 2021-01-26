<template>
  <b-button v-show="!isNew && !isClone"
    size="sm" variant="secondary" class="ml-2" :href="`/portal_preview/captive-portal?PORTAL=${id}`" target="_blank">
    {{ $t('Preview') }} <icon class="ml-1" name="external-link-alt"></icon>
  </b-button>
</template>
<script>
const props = {
  id: {
    type: String
  },
  isClone: {
    type: Boolean
  },
  isNew: {
    type: Boolean
  }
}

// @vue/component
export default {
  name: 'button-preview-portal',
  inheritAttrs: false,
  props
}
</script>
