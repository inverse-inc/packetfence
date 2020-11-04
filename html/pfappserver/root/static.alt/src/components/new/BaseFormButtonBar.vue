<template>
  <div>
    <base-button-save
      :isLoading="isLoading"
      :disabled="!isValid"
      class="mr-1"
      @click="onSave"
    >
      <template v-if="isNew">{{ $t('Create') }}</template>
      <template v-else-if="isClone">{{ $t('Clone') }}</template>
      <template v-else-if="actionKey">{{ $t('Save & Close') }}</template>
      <template v-else>{{ $t('Save') }}</template>
    </base-button-save>
    <b-button
      :disabled="isLoading"
      class="mr-1" variant="outline-secondary"
      @click="onReset"
    >{{ $t('Reset') }}</b-button>
    <b-button v-if="!isNew && !isClone"
      :disabled="isLoading"
      class="mr-1" variant="outline-primary"
      @click="onClone"
    >{{ $t('Clone') }}</b-button>
    <base-button-delete v-if="isDeletable"
      :confirm="$t('Delete?')"
      :disabled="isLoading"
      class="mr-1"
      @delete="onRemove"
    />
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
    onClone,
    onRemove,
    onReset,
    onSave
  } = useFormButtonBar(props, context)

  return {
    onClone,
    onRemove,
    onReset,
    onSave
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
