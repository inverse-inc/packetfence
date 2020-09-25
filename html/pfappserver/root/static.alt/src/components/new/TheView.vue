<template>
  <b-form @submit.prevent="doSave" ref="rootRef">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="doClose" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"/></b-button-close>
        <h4 class="d-inline mb-0" v-html="titleLabel"/>
        <b-badge v-if="titleBadge" class="ml-2" variant="secondary" v-t="titleBadge"/>
      </b-card-header>
      <the-form class="card-body the-form"
        :id="id"
        :form="form"
        :meta="meta"
        :isNew="isNew"
        :isClone="isClone"
        :isLoading="isLoading"
        v-bind="customProps"
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
<style lang="scss">
.the-form {
  padding-top: 1rem !important;
  padding-right: 0;
  padding-bottom: 0;
  padding-left: 0;

  & > .form-group {
    margin-left: 1rem !important;
    margin-right: 1rem !important;
  }
  & > .tabs > .tab-content > .tab-pane {
    padding-top: 1rem !important;
    padding-right: 1rem !important;
    padding-left: 1rem !important;
  }
}
</style>
