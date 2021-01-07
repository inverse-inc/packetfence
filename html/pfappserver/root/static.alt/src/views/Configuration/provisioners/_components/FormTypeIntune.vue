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

    <form-group-oses namespace="oses"
      :column-label="$i18n.t('OS')"
      :text="$i18n.t('Nodes with the selected OS will be affected.')"
    />

    <form-group-application-identifier namespace="applicationID"
      :column-label="$i18n.t('Application ID')"
    />

    <form-group-application-secret namespace="applicationSecret"
      :column-label="$i18n.t('Application Secret')"
    />

    <form-group-tenant-identifier namespace="tenantID"
      :column-label="$i18n.t('Tenant ID')"
    />

    <form-group-host namespace="host"
      :column-label="$i18n.t('Host')"
    />

    <form-group-port namespace="port"
      :column-label="$i18n.t('Port')"
    />

    <form-group-protocol namespace="protocol"
      :column-label="$i18n.t('Protocol')"
    />

    <form-group-login-url namespace="loginUrl"
      :column-label="$i18n.t('Login URL')"
    />

    <form-group-android-agent-download-uri namespace="android_agent_download_uri"
      :column-label="$i18n.t('Android agent download URI')"
    />

    <form-group-ios-agent-download-uri namespace="ios_agent_download_uri"
      :column-label="$i18n.t('IOS agent download URI')"
    />

    <form-group-windows-agent-download-uri namespace="windows_agent_download_uri"
      :column-label="$i18n.t('Windows agent download URI')"
    />

    <form-group-mac-osx-agent-download-uri namespace="mac_osx_agent_download_uri"
      :column-label="$i18n.t('Mac OSX agent download URI')"
    />

    <form-group-domains namespace="domains"
      :column-label="$i18n.t('Authorized domains')"
      :text="$i18n.t('A comma-separated list of domains that will be resolved with the correct IP addresses.')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupAndroidAgentDownloadUri,
  FormGroupApplicationIdentifier,
  FormGroupApplicationSecret,
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupDomains,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupIosAgentDownloadUri,
  FormGroupLoginUrl,
  FormGroupMacOsxAgentDownloadUri,
  FormGroupOses,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupRoleToApply,
  FormGroupTenantIdentifier,
  FormGroupWindowsAgentDownloadUri
} from './'

const components = {
  BaseForm,

  FormGroupAndroidAgentDownloadUri,
  FormGroupApplicationIdentifier,
  FormGroupApplicationSecret,
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupDomains,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupIosAgentDownloadUri,
  FormGroupLoginUrl,
  FormGroupMacOsxAgentDownloadUri,
  FormGroupOses,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupRoleToApply,
  FormGroupTenantIdentifier,
  FormGroupWindowsAgentDownloadUri
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-intune',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
