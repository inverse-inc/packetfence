<template>
  <div>
    <pf-button-save
      :isLoading="formIsLoading"
      class="mr-1"
      @click="onSave"
    >
      <template v-if="formIsNew">{{ $t('Create') }}</template>
      <template v-else-if="formIsClone">{{ $t('Clone') }}</template>
      <template v-else-if="actionKey">{{ $t('Save & Close') }}</template>
      <template v-else>{{ $t('Save') }}</template>
    </pf-button-save>
    <b-button
      :disabled="formIsLoading"
      class="mr-1" variant="outline-secondary"
      @click="onReset"
    >{{ $t('Reset') }}</b-button>
    <b-button v-if="!formIsNew && !formIsClone"
      :disabled="formIsLoading"
      class="mr-1" variant="outline-primary"
      @click="onClone"
    >{{ $t('Clone') }}</b-button>
    <pf-button-delete v-if="isDeletable"
      :confirm="$t('Delete?')"
      :disabled="isLoading"
      class="mr-1"
      @on-delete="onRemove"
    />
    <slot/>
  </div>
</template>
<script>
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import { useFormButtonBar, useFormButtonBarProps } from '@/composables/useFormButtonBar'

export const props = {
  ...useFormButtonBarProps
}

export const setup = (props, context) => {
  const {
    isClone,
    isNew,
    isLoading,
    actionKey,

    onClone,
    onRemove,
    onReset,
    onSave
  } = useFormButtonBar(props, context)

  return {
    formIsClone: isClone,
    formIsNew: isNew,
    formIsLoading: isLoading,
    actionKey,

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
  components: {
    pfButtonDelete,
    pfButtonSave
  },
  props,
  setup
}
</script>
