<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Identifier')"
      :disabled="!isNew && !isClone"
    />

    <form-group-cert namespace="cert"
      :column-label="$i18n.t('Certificate')"
      auto-fit
    />

    <form-group-ca namespace="ca"
      :column-label="$i18n.t('Certificate Authority')"
      auto-fit
    />

    <form-group-key namespace="key"
      :column-label="$i18n.t('Private Key')"
      auto-fit
    />

    <form-group-private-key-password namespace="private_key_password"
      :column-label="$i18n.t('Private Key Password')"
      :text="$i18n.t('Only if needed.')"
    />

    <form-group-intermediate namespace="intermediate"
      :column-label="$i18n.t('Intermediate CA certificate(s)')"
      auto-fit
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
  FormGroupCert,
  FormGroupCa,
  FormGroupKey,
  FormGroupPrivateKeyPassword,
  FormGroupIntermediate
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupCert,
  FormGroupCa,
  FormGroupKey,
  FormGroupPrivateKeyPassword,
  FormGroupIntermediate
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
