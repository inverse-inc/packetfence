<template>
  <b-alert :show="isModified" variant="warning" fade>
    <h4 class="alert-heading" v-t="'Warning'"/>
    <p>
      {{ $t('Some services must be restarted to load the new settings.') }}
      <span v-html="$t('Creating or modifying the monit configuration requires to restart the monit service.')"></span>
    </p>
    <base-button-system-service service="monit" restart start stop
      :disabled="isLoading" class="mr-1" size="sm"/>
  </b-alert>
</template>
<script>
import {
  BaseButtonSystemService
} from '@/components/new/'
const components = {
  BaseButtonSystemService
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

