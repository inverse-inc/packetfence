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

    <form-group-username namespace="username"
      :column-label="$i18n.t('Username')"
    />

    <form-group-password namespace="password"
      :column-label="$i18n.t('Client Secret')"
    />

    <form-group-host namespace="host"
      :column-label="$i18n.t('Host')"
    />

    <form-group-android-download-uri namespace="android_download_uri"
      :column-label="$i18n.t('Android download URI')"
    />

    <form-group-ios-download-uri namespace="ios_download_uri"
      :column-label="$i18n.t('IOS download URI')"
    />

    <form-group-windows-phone-download-uri namespace="windows_phone_download_uri"
      :column-label="$i18n.t('Windows phone download URI')"
    />

    <form-group-boarding-host namespace="boarding_host"
      :column-label="$i18n.t('Boarding host')"
    />

    <form-group-boarding-port namespace="boarding_port"
      :column-label="$i18n.t('Boarding port')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
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
  FormGroupUsername,
  FormGroupWindowsPhoneDownloadUri
} from './'

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
  FormGroupUsername,
  FormGroupWindowsPhoneDownloadUri
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-mobileiron',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
