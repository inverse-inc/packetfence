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

    <form-group-username :column-label="$i18n.t('Username')"
                         namespace="username"
    />

    <form-group-password :column-label="$i18n.t('Client Secret')"
                         namespace="password"
    />

    <form-group-host :column-label="$i18n.t('Host')"
                     namespace="host"
    />

    <form-group-android-download-uri :column-label="$i18n.t('Android download URI')"
                                     namespace="android_download_uri"
    />

    <form-group-ios-download-uri :column-label="$i18n.t('IOS download URI')"
                                 namespace="ios_download_uri"
    />

    <form-group-windows-phone-download-uri :column-label="$i18n.t('Windows phone download URI')"
                                           namespace="windows_phone_download_uri"
    />

    <form-group-boarding-host :column-label="$i18n.t('Boarding host')"
                              namespace="boarding_host"
    />

    <form-group-boarding-port :column-label="$i18n.t('Boarding port')"
                              namespace="boarding_port"
    />
  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
import {
  FormGroupAndroidDownloadUri,
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupBoardingHost,
  FormGroupBoardingPort,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupIosDownloadUri,
  FormGroupOses,
  FormGroupPassword,
  FormGroupRoleToApply,
  FormGroupRules,
  FormGroupUsername,
  FormGroupWindowsPhoneDownloadUri
} from './'
import {useForm as setup, useFormProps as props} from '../_composables/useForm'

const components = {
  BaseForm,

  FormGroupAndroidDownloadUri,
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupBoardingHost,
  FormGroupBoardingPort,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupIosDownloadUri,
  FormGroupOses,
  FormGroupPassword,
  FormGroupRoleToApply,
  FormGroupRules,
  FormGroupUsername,
  FormGroupWindowsPhoneDownloadUri
}

// @vue/component
export default {
  name: 'form-type-mobileiron',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
