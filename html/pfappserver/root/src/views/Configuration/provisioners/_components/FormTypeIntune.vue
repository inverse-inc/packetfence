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

    <form-group-oses :column-label="$i18n.t('OS')"
                     :text="$i18n.t('Nodes with the selected OS will be affected.')"
                     namespace="oses"
    />

    <form-group-rules :column-label="$i18n.t('Rules')"
                     :text="$i18n.t('Rules to apply.')"
                     namespace="rules"
    />

    <form-group-non-compliance-security-event :column-label="$i18n.t('Non compliance security event')"
                                              :text="$i18n.t('Which security event should be raised when non compliance is detected.')"
                                              namespace="non_compliance_security_event"
    />

    <form-group-application-identifier :column-label="$i18n.t('Application ID')"
                                       namespace="applicationID"
    />

    <form-group-application-secret :column-label="$i18n.t('Application Secret')"
                                   namespace="applicationSecret"
    />

    <form-group-tenant-identifier :column-label="$i18n.t('Tenant ID')"
                                  namespace="tenantID"
    />

    <form-group-host :column-label="$i18n.t('Host')"
                     namespace="host"
    />

    <form-group-port :column-label="$i18n.t('Port')"
                     namespace="port"
    />

    <form-group-protocol :column-label="$i18n.t('Protocol')"
                         namespace="protocol"
    />

    <form-group-login-url :column-label="$i18n.t('Login URL')"
                          namespace="loginUrl"
    />

    <form-group-android-agent-download-uri :column-label="$i18n.t('Android agent download URI')"
                                           namespace="android_agent_download_uri"
    />

    <form-group-ios-agent-download-uri :column-label="$i18n.t('IOS agent download URI')"
                                       namespace="ios_agent_download_uri"
    />

    <form-group-windows-agent-download-uri :column-label="$i18n.t('Windows agent download URI')"
                                           namespace="windows_agent_download_uri"
    />

    <form-group-mac-osx-agent-download-uri :column-label="$i18n.t('Mac OSX agent download URI')"
                                           namespace="mac_osx_agent_download_uri"
    />

    <form-group-domains :column-label="$i18n.t('Authorized domains')"
                        :text="$i18n.t('A comma-separated list of domains that will be resolved with the correct IP addresses.')"
                        namespace="domains"
    />
  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
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
  FormGroupNonComplianceSecurityEvent,
  FormGroupOses,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupRoleToApply,
  FormGroupRules,
  FormGroupTenantIdentifier,
  FormGroupWindowsAgentDownloadUri
} from './'
import {useForm as setup, useFormProps as props} from '../_composables/useForm'

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
  FormGroupNonComplianceSecurityEvent,
  FormGroupOses,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupRoleToApply,
  FormGroupRules,
  FormGroupTenantIdentifier,
  FormGroupWindowsAgentDownloadUri
}

// @vue/component
export default {
  name: 'form-type-intune',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
