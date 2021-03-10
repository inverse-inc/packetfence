<template>
  <base-form
    :form="form"
    :schema="schema"
    :isLoading="isLoading"
  >

    <form-group-identifier v-show="!isNew && !isClone"
      namespace="id"
      :column-label="$i18n.t('Identifier')"
      :disabled="true"
    />

    <form-group-dhcp-fingerprint-identifier namespace="dhcp_fingerprint_id"
      :column-label="$i18n.t('DHCP Fingerprint')"
    />

    <form-group-dhcp-vendor-identifier namespace="dhcp_vendor_id"
      :column-label="$i18n.t('DHCP Vendor')"
    />

    <form-group-dhcpv6-fingerprint-identifier namespace="dhcp6_fingerprint_id"
      :column-label="$i18n.t('DHCPv6 Fingerprint')"
    />

    <form-group-dhcpv6-enterprise-identifier namespace="dhcp6_enterprise_id"
      :column-label="$i18n.t('DHCPv6 Enterprise')"
    />

    <form-group-mac-vendor-identifier namespace="mac_vendor_id"
      :column-label="$i18n.t('MAC Vendor (OUI)')"
    />

    <form-group-user-agent-identifier namespace="user_agent_id"
      :column-label="$i18n.t('User Agent')"
    />

    <form-group-device-identifier namespace="device_id"
      :column-label="$i18n.t('Device')"
    />

    <form-group-version namespace="version"
      :column-label="$i18n.t('Version')"
    />

    <form-group-score namespace="score"
      :column-label="$i18n.t('Score')"
    />

  </base-form>
</template>
<script>
import {
  BaseForm
} from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupDeviceIdentifier,
  FormGroupDhcpFingerprintIdentifier,
  FormGroupDhcpVendorIdentifier,
  FormGroupDhcpv6EnterpriseIdentifier,
  FormGroupDhcpv6FingerprintIdentifier,
  FormGroupMacVendorIdentifier,
  FormGroupUserAgentIdentifier,
  FormGroupScore,
  FormGroupVersion,
} from './'

const components = {
  BaseForm,
  FormGroupIdentifier,
  FormGroupDeviceIdentifier,
  FormGroupDhcpFingerprintIdentifier,
  FormGroupDhcpVendorIdentifier,
  FormGroupDhcpv6EnterpriseIdentifier,
  FormGroupDhcpv6FingerprintIdentifier,
  FormGroupMacVendorIdentifier,
  FormGroupUserAgentIdentifier,
  FormGroupScore,
  FormGroupVersion
}

import { useForm, useFormProps as props } from '../_composables/useForm'

export const setup = (props, context) => useForm(props, context)

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

