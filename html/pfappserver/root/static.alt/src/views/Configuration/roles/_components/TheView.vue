<template>
  <b-form @submit.prevent="doSave" ref="rootRef">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="doClose" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0" v-html="titleLabel"></h4>
      </b-card-header>
      <the-form class="card-body"
        :form="form"
        :meta="meta"
        :isNew="viewIsNew"
        :isClone="viewIsClone"
        :isLoading="viewIsLoading"
      />
      <b-card-footer>
        <form-button-bar
          :isNew="viewIsNew"
          :isClone="viewIsClone"
          :isLoading="viewIsLoading"
          :isDeletable="isDeletable"
          :isValid="isValid"
          :formRef="rootRef"
          @clone="doClone"
          @remove="doRemove"
          @reset="doReset"
          @save="doSave"
        >
          <span>Extra Slot</span>
        </form-button-bar>
      </b-card-footer>
    </b-card>
  </b-form>
</template>
<script>
import {
  FormButtonBar,
  TheForm
} from './'
import { useView, useViewProps } from '../_composables/useView'

export const props = {  // from router
  ...useViewProps
}

export const setup = (props, context) => {

  const {
    rootRef,

    isClone,
    isNew,
    isLoading,
    isDeletable,
    isValid,

    titleLabel,
    form,
    meta,

    doClone,
    doClose,
    doRemove,
    doReset,
    doSave
  } = useView(props, context)

  return {
    rootRef,

    viewIsClone: isClone,
    viewIsNew: isNew,
    viewIsLoading: isLoading,
    isValid,
    isDeletable,

    titleLabel,
    form,
    meta,

    doClone,
    doClose,
    doRemove,
    doReset,
    doSave
  }
}

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  components: {
    FormButtonBar,
    TheForm
  },
  props,
  setup
}
</script>
