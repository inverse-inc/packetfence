<template>
  <base-view>
    <template v-slot:header>
      <b-button-close @click="doClose" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"/></b-button-close>
      <h4 class="d-inline mb-0" v-html="titleLabel"/>
      <b-badge v-if="titleBadge" class="ml-2" variant="secondary" v-t="titleBadge"/>
    </template>
    <b-form @submit.prevent="doSave" ref="rootRef">
      <the-form
        :form="form"
        :meta="meta"
        :isNew="isNew"
        :isClone="isClone"
        :isLoading="isLoading"

        :id="id"
      />
    </b-form>
    <template v-slot:footer>
      <form-button-bar
        :actionKey="actionKey"
        :isNew="isNew"
        :isClone="isClone"
        :isLoading="isLoading"
        :isDeletable="isDeletable"
        :isValid="isValid"
        :formRef="rootRef"
        @clone="doClone"
        @remove="doRemove"
        @reset="doReset"
        @save="doSave"
      />
    </template>
  </base-view>
</template>
<script>
import BaseView from '@/components/new/BaseView'
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
