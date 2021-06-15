<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier
      namespace="id"
      :column-label="$i18n.t('MAC Address')"
      :disabled="!isNew && !isClone"
    />

    <form-group-ip
      namespace="ip"
      :column-label="$i18n.t('IP Address')"
    />

    <form-group-pvid
      namespace="pvid"
      :column-label="$i18n.t('Native VLAN')"
      :text="$i18n.t('VLAN in which PacketFence should put the port.')"
    />

    <form-group-trunk-port
      namespace="trunkPort"
      :column-label="$i18n.t('Trunk Port')"
      :text="$i18n.t('The port must be configured as a muti-vlan port.')"
    />

    <form-group-tagged-vlan v-show="form.trunkPort === 'yes'"
      namespace="taggedVlan"
      :column-label="$i18n.t('Tagged VLANs')"
      :text="$i18n.t('Comma separated list of VLANs. If the port is a multi-vlan, these are the VLANs that have to be tagged on the port.')"
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
  FormGroupPvid,
  FormGroupTrunkPort,
  FormGroupTaggedVlan
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupIp,
  FormGroupPvid,
  FormGroupTrunkPort,
  FormGroupTaggedVlan
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

