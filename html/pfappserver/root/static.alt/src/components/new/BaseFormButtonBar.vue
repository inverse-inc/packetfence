<template>
  <div class="d-inline">
    <b-button-group class="mr-1">
      <base-button-save v-if="canSave"
        :isLoading="isLoading"
        :disabled="!isValid"
        @click="onSave"
      >
        {{ saveButtonLabel }}
        <!---
        <template v-if="isNew">{{ $t('Create') }}</template>
        <template v-else-if="actionKey && isClone && canClose">{{ $t('Create & {actionKeyButtonVerb}', { actionKeyButtonVerb }) }}</template>
        <template v-else-if="isClone">{{ $t('Create') }}</template>
        <template v-else-if="actionKey">{{ $t('Save & {actionKeyButtonVerb}', { actionKeyButtonVerb }) }}</template>
        <template v-else>{{ $t('Save') }}</template>
        --->
      </base-button-save>
      <b-button v-if="canClone"
        :disabled="isLoading"
        variant="outline-primary"
        @click="onClone"
      >{{ $t('Clone') }}</b-button>
    </b-button-group>
    <b-button-group class="mr-1">
      <b-button
        :disabled="isLoading"
        variant="outline-secondary"
        @click="onReset"
      >{{ $t('Reset') }}</b-button>
      <b-button v-if="canClose"
        :disabled="isLoading"
        variant="secondary"
        @click="onClose"
      >{{ $t('Cancel') }}</b-button>
    </b-button-group>
    <base-button-confirm v-if="canDelete"
      :label="$t('Delete')"
      :confirm="$t('Delete?')"
      :disabled="isLoading"
      @click="onRemove"
    >{{ $t(' Delete' ) }}</base-button-confirm>
    <slot/>
  </div>
</template>
<script>
import BaseButtonConfirm from './BaseButtonConfirm'
import BaseButtonSave from './BaseButtonSave'

const components = {
  BaseButtonConfirm,
  BaseButtonSave
}

import { useFormButtonBar, useFormButtonBarProps } from '@/composables/useFormButtonBar'

export const props = {
  ...useFormButtonBarProps
}

export const setup = (props, context) => {
  const {
    canClone,
    canClose,
    canDelete,
    canSave,
    onClone,
    onClose,
    onRemove,
    onReset,
    onSave,
    saveButtonLabel
  } = useFormButtonBar(props, context)

  return {
    canClone,
    canClose,
    canDelete,
    canSave,
    onClone,
    onClose,
    onRemove,
    onReset,
    onSave,
    saveButtonLabel
  }
}

// @vue/component
export default {
  name: 'base-form-button-bar',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
