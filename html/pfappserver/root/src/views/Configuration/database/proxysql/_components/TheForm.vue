<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-status namespace="status"
                       :column-label="$i18n.t('Remote Database')"
                       :text="$i18n.t('Enable external remote database on ProxySQL')"
                       enabled-value="enabled"
                       disabled-value="disabled"
    />

    <form-group-cacert namespace="cacert"
                       :column-label="$i18n.t('CA Certificate')"
                       :text="$i18n.t('Database CA Certificate')"
    />

    <form-group-backend namespace="backend"
                        :column-label="$i18n.t('Host')"
                        :text="$i18n.t('Database Host')"
    />

    <form-group-backend-port namespace="backend_port"
                        :column-label="$i18n.t('Port')"
                        :text="$i18n.t('Database Port')"
    />

    <form-group-encryption namespace="encryption"
                        :column-label="$i18n.t('Encryption')"
                        :text="$i18n.t('Database Encryption')"
    />

  </base-form>
</template>
<script>
import {computed} from '@vue/composition-api'
import {BaseForm} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupBackend,
  FormGroupCacert,
  FormGroupEncryption,
  FormGroupBackendPort,
  FormGroupStatus
} from './'

const components = {
  BaseForm,

  FormGroupCacert,
  FormGroupBackend,
  FormGroupStatus,
  FormGroupBackendPort,
  FormGroupEncryption,
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

