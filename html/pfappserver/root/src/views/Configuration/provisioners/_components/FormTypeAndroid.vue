<template>
  <base-form
    :form="form"
    :isLoading="isLoading"
    :meta="meta"
    :schema="schema"
  >
    <form-group-identifier :column-label="$i18n.t('Provisioning ID')"
                           :disabled="!isNew && !isClone"
                           namespace="id"
    />

    <form-group-description :column-label="$i18n.t('Description')"
                            namespace="description"
    />

    <form-group-enforce :column-label="$i18n.t('Enforce')"
                        :text="$i18n.t('Whether or not the provisioner should be enforced. This will trigger checks to validate the device is compliant with the provisioner during RADIUS authentication and on the captive portal.')"
                        disabled-value="disabled"
                        enabled-value="enabled"
                        namespace="enforce"
    />

    <form-group-auto-register :column-label="$i18n.t('Auto register')"
                              :text="$i18n.t('Whether or not devices should be automatically registered on the network if they are authorized in the provisioner.')"
                              disabled-value="disabled"
                              enabled-value="enabled"
                              namespace="autoregister"
    />

    <form-group-apply-role :column-label="$i18n.t('Apply role')"
                           :text="$i18n.t('When enabled, this will apply the configured role to the endpoint if it is authorized in the provisioner.')"
                           disabled-value="disabled"
                           enabled-value="enabled"
                           namespace="apply_role"
    />

    <form-group-role-to-apply :column-label="$i18n.t('Role to apply')"
                              :text="$i18n.t(`When 'Apply role' is enabled, this defines the role to apply when the device is authorized with the provisioner.`)"
                              namespace="role_to_apply"
    />

    <form-group-category :column-label="$i18n.t('Roles')"
                         :text="$i18n.t('Nodes with the selected roles will be affected.')"
                         namespace="category"
    />

    <form-group-rules :column-label="$i18n.t('Rules')"
                     :text="$i18n.t('Rules to apply.')"
                     namespace="rules"
    />

    <form-group-ssid :column-label="$i18n.t('SSID')"
                     namespace="ssid"
    />

    <form-group-broadcast :column-label="$i18n.t('Broadcast network')"
                          :disabled-value="0"
                          :enabled-value="1"
                          :text="$i18n.t('Disable this box if you are using a hidden SSID.')"
                          namespace="broadcast"
    />

    <form-group-security-type :column-label="$i18n.t('Security type')"
                              :text="$i18n.t('Select the type of security applied for your SSID.')"
                              namespace="security_type"
    />

    <form-group-eap-type v-if="wantsEapType"
                         :column-label="$i18n.t('EAP type')"
                         :text="$i18n.t('Select the EAP type of your SSID. Leave empty for no EAP.')"
                         namespace="eap_type"
    />

    <form-group-dpsk v-if="wantsDpsk"
                     :column-label="$i18n.t('Enable DPSK')"
                     :text="$i18n.t('Define if the PSK needs to be generated.')"
                     disabled-value="0"
                     enabled-value="1"
                     namespace="dpsk"
    />

    <form-group-dpsk-use-local-password v-if="wantsDpsk"
                                        :column-label="$i18n.t('Reuse the local password for DPSK')"
                                        :text="$i18n.t('When DPSK is enabled and a local account with a plaintext password exists for the user, then it will reuse this password instead of generating a new PSK. This feature will only work with local users that have a plaintext password entry.')"
                                        disabled-value="disabled"
                                        enabled-value="enabled"
                                        namespace="dpsk_use_local_password"
    />

    <form-group-passcode v-if="wantsPasscode"
                         :column-label="$i18n.t('Wifi Key')"
                         namespace="passcode"
    />

    <form-group-server-certificate-path v-if="wantsServerCertificatePath"
                                        :column-label="$i18n.t('RADIUS server certificate file')"
                                        :text="$i18n.t('The path to the RADIUS server certificate.')"
                                        :title="$i18n.t('Upload RADIUS server certificate file')"
                                        namespace="server_certificate_path"
    />

    <form-group-ca-cert-path v-if="wantsServerRadiusCaPath"
                             :column-label="$i18n.t('RADIUS server CA file')"
                             :text="$i18n.t('The path to the RADIUS server CA which signed the RADIUS server certificate.')"
                             :title="$i18n.t('Upload RADIUS server CA file')"
                             namespace="ca_cert_path"
    />

    <form-group-pki-provider v-if="wantsPkiProvider"
                             :column-label="$i18n.t('PKI Provider')"
                             namespace="pki_provider"
    />
  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
import {
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupBroadcast,
  FormGroupCaCertPath,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupDpsk,
  FormGroupDpskUseLocalPassword,
  FormGroupEapType,
  FormGroupEnforce,
  FormGroupIdentifier,
  FormGroupPasscode,
  FormGroupPkiProvider,
  FormGroupRoleToApply,
  FormGroupRules,
  FormGroupSecurityType,
  FormGroupServerCertificatePath,
  FormGroupSsid
} from './'
import {useForm as setup, useFormProps as props} from '../_composables/useForm'

const components = {
  BaseForm,

  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupBroadcast,
  FormGroupCaCertPath,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupDpsk,
  FormGroupDpskUseLocalPassword,
  FormGroupEapType,
  FormGroupEnforce,
  FormGroupIdentifier,
  FormGroupPasscode,
  FormGroupPkiProvider,
  FormGroupRoleToApply,
  FormGroupRules,
  FormGroupSecurityType,
  FormGroupServerCertificatePath,
  FormGroupSsid
}

// @vue/component
export default {
  name: 'form-type-android',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
