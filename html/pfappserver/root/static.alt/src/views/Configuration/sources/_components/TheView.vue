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
      <template v-if="samlMetaData">
        <b-button class="ml-1 mr-1" size="sm" variant="outline-secondary" @click="showSaml">{{ $t('View Service Provider Metadata') }}</b-button>
        <b-modal v-model="isSaml" title="Service Provider Metadata" size="lg" centered cancel-disabled>
          <b-form-textarea ref="samlRef" v-model="samlMetaData" :rows="27" :max-rows="27" readonly></b-form-textarea>
          <template v-slot:modal-footer>
            <b-button variant="secondary" class="mr-1" @click="hideSaml">{{ $t('Close') }}</b-button>
            <b-button variant="primary" @click="copySaml">{{ $t('Copy to Clipboard') }}</b-button>
          </template>
        </b-modal>
      </template>
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
