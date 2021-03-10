<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-enabled namespace="enabled"
      :column-label="$i18n.t('Enable MSE')"
      :text="$i18n.t('')"
    />

    <form-group-url namespace="url"
      :column-label="$i18n.t('URL of MSE service')"
      :text="$i18n.t('')"
    />

    <form-group-user namespace="user"
      :column-label="$i18n.t('Username')"
      :text="$i18n.t('Username for MSE service.')"
    />

    <form-group-pass namespace="pass"
      :column-label="$i18n.t('Password')"
      :text="$i18n.t('Password for MSE service.')"
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
  FormGroupEnabled,
  FormGroupPass,
  FormGroupUrl,
  FormGroupUser
} from './'

const components = {
  BaseForm,

  FormGroupEnabled,
  FormGroupPass,
  FormGroupUrl,
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

