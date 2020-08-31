<template>
  <b-form @submit.prevent="doSave" ref="rootRef">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="doClose" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0" v-html="titleLabel"></h4>
      </b-card-header>
      <the-form class="card-body"
        :id="id"
        :form="form"
        :meta="meta"
        :isNew="isNew"
        :isClone="isClone"
        :isLoading="isLoading"
      />
      <b-card-footer>
        <form-button-bar
          :actionKey="actionKey"
          :isNew="isNew"
          :isClone="isClone"
          :isLoading="isLoading"
          :isDeletable="isDeletable"
          :isValid="isValid"
          :formRef="rootRef"
          @create="doCreate"
          @clone="doClone"
          @remove="doRemove"
          @reset="doReset"
          @save="doSave"
        />
      </b-card-footer>
    </b-card>
  </b-form>
</template>
<script>
import { useView, useViewProps } from '@/composables/useView'

const components = {}

export const props = {
  ...useViewProps
}

const setup = (props, context) => {
  return useView(props, context)
}

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
