<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
    :isReadonly="id === 'default' && !isClone"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Identifier')"
      :disabled="!isNew && !isClone"
    />

    <form-group-tls namespace="tls"
      :column-label="$i18n.t('TLS Profile')"
    />

    <form-group-authority-identity namespace="authority_identity"
      :column-label="$i18n.t('Authority Identity')"
    />

    <form-group-pac-opaque-key namespace="pac_opaque_key"
      :column-label="$i18n.t('Key')"
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
  FormGroupTls,
  FormGroupAuthorityIdentity,
  FormGroupPacOpaqueKey
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupTls,
  FormGroupAuthorityIdentity,
  FormGroupPacOpaqueKey
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
