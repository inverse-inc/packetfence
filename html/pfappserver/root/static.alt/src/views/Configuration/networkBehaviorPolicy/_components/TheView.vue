<template>
  <base-view>
    <template v-slot:header>
      <b-button-close @click="onClose" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"/></b-button-close>
      <h4 class="d-inline mb-0" v-html="title"/>
    </template>
    <b-form @submit.prevent="onSave" ref="rootRef">
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
      <b-alert :show="isModified" variant="warning" fade>
        <h4 class="alert-heading" v-t="'Warning'"/>
        <p>
          {{ $t('Some services must be restarted to load the new certificate.') }}
          <span v-html="$t('Creating or modifying a network behavior policy requires to restart the fingerbank-collector service')"></span>
        </p>
        <button-service service="fingerbank-collector" restart start stop
          :disabled="isLoading" class="mr-1" size="sm"/>
      </b-alert>
      <form-button-bar
        :actionKey="actionKey"
        :isNew="isNew"
        :isClone="isClone"
        :isLoading="isLoading"
        :isDeletable="isDeletable"
        :isValid="isValid"
        :formRef="rootRef"
        @clone="onClone"
        @remove="onRemove"
        @reset="onReset"
        @save="onSave"
      />
    </template>
  </base-view>
</template>
<script>
import BaseView from '@/components/new/BaseView'
import {
  ButtonService,
  FormButtonBar,
  TheForm
} from './'

const components = {
  BaseView,

  ButtonService,
  FormButtonBar,
  TheForm
}

const render = BaseView.render

import { useCollectionItemView, useCollectionItemViewProps } from '../../_composables/useCollectionItemView'
import { useCollectionItem, useCollectionItemProps } from '../_composables/useCollection'

const props = {
  ...useCollectionItemViewProps,
  ...useCollectionItemProps
}

const setup = (props, context) => useCollectionItemView(useCollectionItem, props, context)

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
