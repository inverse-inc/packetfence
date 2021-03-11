<template>
  <b-alert :show="isModified" variant="warning" fade>
    <h4 class="alert-heading" v-t="'Warning'"/>
    <p>
      <span v-html="$t('Adding or modifying a network requires a restart of the iptables, pfdhcp and pfdns services for the changes to take place.')"></span>
    </p>
    <base-button-service service="iptables" restart start stop
      :disabled="isLoading" class="mr-1" size="sm"/>
    <base-button-service service="pfdhcp" restart start stop
      :disabled="isLoading" class="mr-1" size="sm"/>
    <base-button-service service="pfdns" restart start stop
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

