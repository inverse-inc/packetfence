<template>
  <b-card no-body>
    <b-card-header>
      <b-button-close @click="onClose" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"/></b-button-close>
      <h4 class="d-inline mb-0" v-html="title"/>
      <b-badge v-if="titleBadge" class="ml-2" variant="secondary" v-t="titleBadge" />
    </b-card-header>
    <b-form @submit.prevent="onSave" ref="rootRef">
      <the-form
        :form="form"
        :meta="meta"
        :id="id"
        :isNew="isNew"
        :isClone="isClone"
        :isLoading="isLoading"
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
        :isDeletable="isDeletable"
        :isValid="isValid"
        :formRef="rootRef"
        @close="onClose"
        @clone="onClone"
        @remove="onRemove"
        @reset="onReset"
        @save="onSave"
      />
      <slot name="buttonsAppend" v-if="$scopedSlots.buttonsAppend" v-bind="scopedSlotProps" />
    </b-card-footer>
  </b-card>
</template>
<script>
import { useViewCollectionItemProps as props } from '../../_composables/useViewCollectionItem'

// @vue/component
export default {
  name: 'base-view-collection-item',
  inheritAttrs: false,
  components: { // component stubs
    'form-button-bar': undefined,
    'the-form': undefined
  },
  props,
  setup: () => ({ // prop stubs
    rootRef: undefined,
    title: undefined,
    titleBadge: undefined,
    form: undefined,
    meta: undefined,
    isLoading: undefined,
    isCloneable: undefined,
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
