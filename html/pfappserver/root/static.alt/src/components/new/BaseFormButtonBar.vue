<template>
  <div class="d-inline">
    <b-button-group class="mr-1">
      <base-button-save
        :isLoading="isLoading"
        :disabled="!isValid"
        @click="onSave"
      >
        <template v-if="isNew">{{ $t('Create') }}</template>
        <template v-else-if="actionKey && isClone && isCloseable">{{ $t('Clone & Close') }}</template>
        <template v-else-if="isClone">{{ $t('Clone') }}</template>
        <template v-else-if="actionKey">{{ $t('Save & Close') }}</template>
        <template v-else>{{ $t('Save') }}</template>
      </base-button-save>
      <b-button v-if="isCloneable"
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
      <b-button v-if="isCloseable"
        :disabled="isLoading"
        variant="secondary"
        @click="onClose"
      >{{ $t('Cancel') }}</b-button>
    </b-button-group>
    <base-button-delete v-if="isDeletable"
      :confirm="$t('Delete?')"
      :disabled="isLoading"
      @delete="onRemove"
    />
    <b-button v-if="isCloseable"
      :disabled="isLoading"
      class="mr-1" variant="secondary"
      @click="onClose"
    >{{ $t('Cancel') }}</b-button>
    <slot/>
  </div>
</template>
<script>
import BaseButtonDelete from './BaseButtonDelete'
import BaseButtonSave from './BaseButtonSave'

const components = {
  BaseButtonDelete,
  BaseButtonSave
}

import { useFormButtonBar, useFormButtonBarProps } from '@/composables/useFormButtonBar'

export const props = {
  ...useFormButtonBarProps
}

export const setup = (props, context) => {
  const {
    isCloneable,
    isCloseable,
    onClone,
    onClose,
    onRemove,
    onReset,
    onSave,
  } = useFormButtonBar(props, context)

  return {
    isCloneable,
    isCloseable,
    onClone,
    onClose,
    onRemove,
    onReset,
    onSave,
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
