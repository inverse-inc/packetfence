<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <the-test v-if="!isNew && !isClone && id"
      :id="id"
      :form="form"
    />

    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Domain')"
      :disabled="!isNew && !isClone"
    />

    <form-group-connector namespace="connector"
      :column-label="$i18n.t('Connector')"
    />
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupConnector,
  TheTest,
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupConnector,
  TheTest,
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

