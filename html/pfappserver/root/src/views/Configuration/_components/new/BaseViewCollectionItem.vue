<template>
  <b-card no-body>
    <b-card-header>
      <b-button-close @click="onClose" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"/></b-button-close>
      <h4 class="d-inline mb-0" v-html="title" />
      <b-badge v-if="titleBadge" class="ml-2" variant="secondary" v-html="titleBadge" />
      <base-button-help v-if="titleHelp"
        class="ml-1" :url="titleHelp" />
      <slot name="headerAppend" v-if="$scopedSlots.headerAppend" v-bind="scopedSlotProps" />
    </b-card-header>
    <b-form @submit.prevent="onSave" ref="rootRef">
      <the-form
        :form="form"
        @form="form = $event"
        :meta="meta"
        :id="id"
        :isNew="isNew"
        :isClone="isClone"
        :isLoading="isLoading"
        :isModified="isModified"
        v-bind="$props"
      />
    </b-form>
    <b-card-footer>
      <slot name="buttonsPrepend" v-if="$scopedSlots.buttonsPrepend" v-bind="scopedSlotProps" />
      <form-button-bar
        :actionKey="actionKey"
        :isNew="isNew"
        :isClone="isClone"
        :isLoading="isLoading"
        :isCloneable="isCloneable"
        :isSaveable="isSaveable"
        :isDeletable="isDeletable"
        :isValid="isValid"
        :formRef="rootRef"
        :labelActionKey="labelActionKey"
        :labelCreate="labelCreate"
        :labelSave="labelSave"
        :confirmSave="confirmSave"
        @close="onClose"
        @clone="onClone"
        @remove="onRemove"
        @reset="onReset"
        @save="onSave"
      />
      <base-services :value="isModified"
        v-bind="services" :title="$i18n.t('Warning')" class="mt-3 mb-0" />
      <slot name="buttonsAppend" v-if="$scopedSlots.buttonsAppend" v-bind="scopedSlotProps" />
    </b-card-footer>
  </b-card>
</template>
<script>
import {
  useViewCollectionItemComponents as components,
  useViewCollectionItemProps as props
} from '../../_composables/useViewCollectionItem'

// @vue/component
export default {
  name: 'base-view-collection-item',
  inheritAttrs: false,
  components: {
    'base-button-help': undefined,
    'base-services': undefined,
    'form-button-bar': undefined,
    'the-form': undefined,
    ...components,
  },
  props,
  setup: () => ({ // prop stubs
    rootRef: undefined,
    title: undefined,
    titleBadge: undefined,
    titleHelp: undefined,
    form: undefined,
    meta: undefined,
    isLoading: undefined,
    isCloneable: undefined,
    isSaveable: undefined,
    isDeletable: undefined,
    isValid: undefined,
    actionKey: undefined,
    onClone: undefined,
    onClose: undefined,
    onRemove: undefined,
    onReset: undefined,
    onSave: undefined,
    scopedSlotProps: {}
  })
}
</script>
