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
      :column-label="$i18n.t('Identifier')"
      :disabled="!isNew && !isClone"
    />

    <form-group-ip namespace="ip"
      :column-label="$i18n.t('IP')"
      :text="$i18n.t('IP of the DNS server.')"
    />

    <form-group-port namespace="port"
      :column-label="$i18n.t('Port')"
      :text="$i18n.t('Port of the DNS server.')"
    />

    <form-group-pfconnector-port namespace="pfconnector_port"
      :column-label="$i18n.t('Connector Port')"
      :text="$i18n.t('Connector port to reach out the DNS server.')"
    />

    <form-group-domains namespace="domains"
      :column-label="$i18n.t('Domains')"
      :text="$i18n.t('Domain(s) name.')"
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
  FormGroupIp,
  FormGroupPort,
  FormGroupPfconnectorPort,
  FormGroupDomains,
  TheTest,
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupIp,
  FormGroupPort,
  FormGroupPfconnectorPort,
  FormGroupDomains,
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

