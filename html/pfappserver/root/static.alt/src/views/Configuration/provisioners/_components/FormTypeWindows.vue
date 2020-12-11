<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('PKI Provider Name')"
      :disabled="!isNew && !isClone"
    />

    <form-group-description namespace="description"
      :column-label="$i18n.t('Description')"
    />

    <form-group-enforce namespace="enforce"
      :column-label="$i18n.t('Enforce')"
      :text="$i18n.t('Whether or not the provisioner should be enforced. This will trigger checks to validate the device is compliant with the provisioner during RADIUS authentication and on the captive portal.')"
    />

    <form-group-auto-register namespace="autoregister"
      :column-label="$i18n.t('Auto register')"
      :text="$i18n.t('Whether or not devices should be automatically registered on the network if they are authorized in the provisioner.')"
    />

    <form-group-apply-role namespace="apply_role"
      :column-label="$i18n.t('Apply role')"
      :text="$i18n.t('When enabled, this will apply the configured role to the endpoint if it is authorized in the provisioner.')"
    />

    <form-group-role-to-apply namespace="role_to_apply"
      :column-label="$i18n.t('Role to apply')"
      :text="$i18n.t(`When 'Apply role' is enabled, this defines the role to apply when the device is authorized with the provisioner.`)"
    />

    <form-group-category namespace="category"
      :column-label="$i18n.t('Roles')"
      :text="$i18n.t('Nodes with the selected roles will be affected.')"
    />

    <form-group-ssid namespace="ssid"
      :column-label="$i18n.t('SSID')"
    />

    <form-group-broadcast namespace="broadcast"
      :column-label="$i18n.t('Broadcast network')"
      :text="$i18n.t('Disable this box if you are using a hidden SSID.')"
    />

    <form-group-security-type namespace="security_type"
      :column-label="$i18n.t('Security type')"
      :text="$i18n.t('Select the type of security applied for your SSID.')"
    />

    <form-group-eap-type v-if="wantsEapType"
      namespace="eap_type"
      :column-label="$i18n.t('EAP type')"
      :text="$i18n.t('Select the EAP type of your SSID. Leave empty for no EAP.')"
    />

    <form-group-dpsk v-if="wantsDpsk"
      namespace="dpsk"
      :column-label="$i18n.t('Enable DPSK')"
      :text="$i18n.t('Define if the PSK needs to be generated.')"
    />

    <form-group-passcode v-if="wantsPasscode"
      namespace="passcode"
      :column-label="$i18n.t('Wifi Key')"
    />

    <form-group-server-certificate-path v-if="wantsServerCertificatePath"
      namespace="server_certificate_path"
      :column-label="$i18n.t('RADIUS server certificate path')"
      :text="$i18n.t('The path to the RADIUS server certificate.')"
    />

    <form-group-ca-cert-path v-if="wantsServerRadiusCaPath"
      namespace="ca_cert_path"
      :column-label="$i18n.t('RADIUS server CA path')"
      :text="$i18n.t('The path to the RADIUS server CA which signed the RADIUS server certificate.')"
    />

    <form-group-pki-provider v-if="wantsPkiProvider"
      namespace="pki_provider"
      :column-label="$i18n.t('PKI Provider')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupBroadcast,
  FormGroupCaCertPath,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupDpsk,
  FormGroupEapType,
  FormGroupEnforce,
  FormGroupIdentifier,
  FormGroupPasscode,
  FormGroupPkiProvider,
  FormGroupRoleToApply,
  FormGroupSecurityType,
  FormGroupServerCertificatePath,
  FormGroupSsid
} from './'

const components = {
  BaseForm,

  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupBroadcast,
  FormGroupCaCertPath,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupDpsk,
  FormGroupEapType,
  FormGroupEnforce,
  FormGroupIdentifier,
  FormGroupPasscode,
  FormGroupPkiProvider,
  FormGroupRoleToApply,
  FormGroupSecurityType,
  FormGroupServerCertificatePath,
  FormGroupSsid
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-windows',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
