<template>
  <base-button-service service="kafka" restart start stop
    size="sm" class="float-right" />
</template>
<script>
import {
  BaseButtonService
} from '@/components/new/'

const components = {
  BaseButtonService
}

// @vue/component
export default {
  name: 'button-service-kafka',
  inheritAttrs: false,
  components
}
</script>
