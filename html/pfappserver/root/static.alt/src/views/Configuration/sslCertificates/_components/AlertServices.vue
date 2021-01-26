<template>
  <b-alert :show="show" variant="warning" fade>
    <h4 class="alert-heading" v-t="'Warning'"/>
    <p v-t="'Some services must be restarted to load the new certificate.'"/>
    <base-button-service v-for="service in services" :key="service"
      :service="service"
      :disabled="disabled"
      class="mr-1"
      restart start stop
    />
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
  disabled: {
    type: Boolean
  },
  show: {
    type: Boolean
  },
  services: {
    type: Array
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

