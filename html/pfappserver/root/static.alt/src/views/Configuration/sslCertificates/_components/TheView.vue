<template>
  <base-view>
    <template v-slot:header>
      <h4 class="mb-0" v-html="'SSL Certificates'"/>
    </template>
    <b-tabs v-model="tabIndex" card>
      <view-tab-http :active="tabIndex === 0" />
      <view-tab-radius :active="tabIndex === 1" />
    </b-tabs>
  </base-view>
</template>
<script>
import { useView, useViewProps } from '../_composables/useView'
import BaseView from '@/components/new/BaseView'
import ViewTabHttp from './ViewTabHttp'
import ViewTabRadius from './ViewTabRadius'

const components = {
  BaseView,

  ViewTabHttp,
  ViewTabRadius,
}

const props = useViewProps

const render = BaseView.render

const setup = (props, context) => useView(props, context)

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  components,
  props,
  render,
  setup
}
</script>
