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

      <form-group-description namespace="description"
        :column-label="$i18n.t('Description')"
      />

      <form-group-secret namespace="secret"
        :column-label="$i18n.t('Secret')"
      />
    
      <form-group-networks namespace="networks"
        :column-label="$i18n.t('Networks')"
        :text="$i18n.t('Outbound networks for which this connector should be used. When a network matches multiple connectors, a top-down match is performed based on their order in the configuration. This filtering only applies when PacketFence performs outbound traffic to a server or equipment via the connector, not when receiving inbound traffic.')"
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
  FormGroupDescription,
  FormGroupNetworks,
  FormGroupSecret
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupNetworks,
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

