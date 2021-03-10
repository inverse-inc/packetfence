<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-user namespace="user"
      :column-label="$i18n.t('Username')"
      :text="$i18n.t('The webservices user name.')"
    />

    <form-group-pass namespace="pass"
      :column-label="$i18n.t('Password')"
      :text="$i18n.t('The webservices password.')"
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
  FormGroupPass,
  FormGroupUser
} from './'

const components = {
  BaseForm,

  FormGroupPass,
  FormGroupUser
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
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

