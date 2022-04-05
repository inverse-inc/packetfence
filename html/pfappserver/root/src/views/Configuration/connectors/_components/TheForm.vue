<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
      <form-group-identifier namespace="id"
        :column-label="$i18n.t('Connector ID')"
        :disabled="!isNew && !isClone"
      />

      <form-group-secret namespace="secret"
        :column-label="$i18n.t('Secret')"
      />
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm,
  BaseFormTab
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupSecret
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupSecret
}

export const props = {
  id: {
    type: String
  },
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props) => {
  const schema = computed(() => schemaFn(props))

  return {
    schema
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

