<template>
  <base-view>
    <template v-slot:header>
      <h4 class="d-inline mb-0" v-html="titleLabel"/>
    </template>
    <b-form @submit.prevent="doSave" ref="rootRef">
      <the-form
        :form="form"
        :meta="meta"
        :isLoading="isLoading"
      />
    </b-form>
    <template v-slot:footer>
      <form-button-bar
        :isLoading="isLoading"
        :isValid="isValid"
        :formRef="rootRef"
        @reset="doReset"
        @save="doSave"
      />
    </template>
  </base-view>
</template>
<script>
import { BaseView } from '@/components/new'
import { useView, useViewProps } from '../_composables/useView'
import {
  FormButtonBar,
  TheForm
} from './'

const components = {
  BaseView,

  FormButtonBar,
  TheForm
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
