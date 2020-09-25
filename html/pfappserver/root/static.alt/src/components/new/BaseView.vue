<template>
  <b-card no-body>
    <b-card-header>
      <slot name="header"/>
    </b-card-header>
    <slot name="default" class="card-body"/>
    <b-card-footer>
      <slot name="footer"/>
    </b-card-footer>
  </b-card>
</template>
<script>
/*
import { useView, useViewProps } from '@/composables/useView'

const components = {}

export const props = {
  ...useViewProps
}

const setup = (props, context) => {}
*/

// @vue/component
export default {
  name: 'base-view',
  inheritAttrs: false,
/*
  components,
  props,
  setup
*/
}
</script>
