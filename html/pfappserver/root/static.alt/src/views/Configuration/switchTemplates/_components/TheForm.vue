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

    <form-group-description namespace="description"
      :column-label="$i18n.t('Decription')"
    />

    <form-group-radius-disconnect namespace="radiusDisconnect"
      :column-label="$i18n.t('RADIUS Disconnect')"
    />

    <form-group-snmp-disconnect namespace="snmpDisconnect"
      :column-label="$i18n.t('SNMP Disconnect')"
      :text="$i18n.t('Use SNMP instead of RADIUS to perform access reevaluation. This will perform an SNMP up/down on the port using the standard MIB.')"
    />

    <form-group-accept-vlans namespace="acceptVlan"
      :column-label="$i18n.t('Accept VLAN Scope')"
    />

    <form-group-accept-roles namespace="acceptRole"
      :column-label="$i18n.t('Accept Role Scope')"
    />

    <form-group-disconnect namespace="disconnect"
      :column-label="$i18n.t('Disconnect Scope')"
    />

    <form-group-coa namespace="coa"
      :column-label="$i18n.t('CoA Scope')"
    />

    <form-group-coa namespace="reject"
      :column-label="$i18n.t('Reject Scope')"
    />

    <form-group-voip namespace="voip"
      :column-label="$i18n.t('VOIP Scope')"
    />

    <form-group-bounce namespace="bounce"
      :column-label="$i18n.t('Bounce Port Scope')"
    />

    <form-group-acl-template namespace="acl_template"
      :column-label="$i18n.t('ACL template')"
      :text="$i18n.t('The template to use to generate an access list for this module.')"
    />

    <form-group-cli-authorize-read namespace="cliAuthorizeRead"
      :column-label="$i18n.t('CLI Authorize Read Scope')"
    />

    <form-group-cli-authorize-write namespace="cliAuthorizeWrite"
      :column-label="$i18n.t('CLI Authorize Write Scope')"
    />

    <form-group-nas-port-to-if-index namespace="nasPortToIfindex"
      :column-label="$i18n.t('NasPortToIfindex template')"
    />
  </base-form>
</template>
<script>
import { computed, onMounted, provide, ref } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupAcceptRoles,
  FormGroupAcceptVlans,
  FormGroupAclTemplate,
  FormGroupBounce,
  FormGroupCliAuthorizeRead,
  FormGroupCliAuthorizeWrite,
  FormGroupCoa,
  FormGroupDescription,
  FormGroupDisconnect,
  FormGroupIdentifier,
  FormGroupNasPortTOIfIndex,
  FormGroupRadiusDisconnect,
  FormGroupReject,
  FormGroupSnmpDisconnect,
  FormGroupVoip,
} from './'

const components = {
  BaseForm,

  FormGroupAcceptRoles,
  FormGroupAcceptVlans,
  FormGroupAclTemplate,
  FormGroupBounce,
  FormGroupCliAuthorizeRead,
  FormGroupCliAuthorizeWrite,
  FormGroupCoa,
  FormGroupDescription,
  FormGroupDisconnect,
  FormGroupIdentifier,
  FormGroupNasPortTOIfIndex,
  FormGroupRadiusDisconnect,
  FormGroupReject,
  FormGroupSnmpDisconnect,
  FormGroupVoip,
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

export const setup = (props, context) => {
  const schema = computed(() => schemaFn(props))

  // provide RADIUS attributes to all child nodes
  const { root: { $store } = {} } = context
  const radiusAttributes = ref({})
  provide('radiusAttributes', radiusAttributes)
  onMounted(() => {
    $store.dispatch('radius/getAttributes').then(_radiusAttributes => {
      radiusAttributes.value = _radiusAttributes
    })
  })

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
