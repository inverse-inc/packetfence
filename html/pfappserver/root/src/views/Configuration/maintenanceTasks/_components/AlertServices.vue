<template>
  <b-alert :show="isModified" variant="warning" fade>
    <h4 class="alert-heading" v-t="'Warning'"/>
    <p>
      {{ $t('Some services must be restarted to load the new settings.') }}
      <span v-html="$t('Creating or modifying the maintenance tasks requires to restart the pfcron service.')"></span>
    </p>
    <base-button-service service="pfcron" restart start stop
      :disabled="isLoading" class="mr-1" size="sm"/>
  </b-alert>
</template>
<script>
import {
  BaseButtonService
} from '@/components/new/'
const components = {
  BaseButtonService
}

const props = {
  isLoading: {
    type: Boolean,
    default: true
  },
  isModified: {
    type: Boolean,
    default: true
  }
}

const setup = () => {}

// @vue/component
export default {
  name: 'alert-services',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

