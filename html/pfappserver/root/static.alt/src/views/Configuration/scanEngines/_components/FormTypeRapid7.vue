<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Name')"
    />

    <form-group-ip namespace="ip"
      :column-label="$i18n.t('Hostname or IP Address')"
    />

    <form-group-username namespace="username"
      :column-label="$i18n.t('Username')"
    />

    <form-group-password namespace="password"
      :column-label="$i18n.t('Password')"
    />

    <form-group-port namespace="port"
      :column-label="$i18n.t('Port of the service')"
      :text="$i18n.t('If you use an alternative port, please specify.')"
    />

    <form-group-verify-hostname namespace="verify_hostname"
      :column-label="$i18n.t('Verify Hostname')"
      :text="$i18n.t('Verify hostname of server when connecting to the API.')"
    />

    <form-group-engine-identifier namespace="engine_id"
      :column-label="$i18n.t('Scan Engine')"
      :text="$i18n.t('After configuring this scan engine for the first time, you will be able to select this attribute from the available ones in Rapid7.')"

    />

    <form-group-template-identifier namespace="template_id"
      :column-label="$i18n.t('Scan Template')"
      :text="$i18n.t('After configuring this scan engine for the first time, you will be able to select this attribute from the available ones in Rapid7.')"
    />

    <form-group-site-identifier namespace="site_id"
      :column-label="$i18n.t('Site')"
      :text="$i18n.t('After configuring this scan engine for the first time, you will be able to select this attribute from the available ones in Rapid7.')"
    />

    <form-group-categories namespace="categories"
      :column-label="$i18n.t('Roles')"
      :text="$i18n.t('Nodes with the selected roles will be affected.')"
    />

    <form-group-oses namespace="oses"
      :column-label="$i18n.t('OS')"
      :text="$i18n.t('Nodes with the selected OS will be affected.')"
    />

    <form-group-duration namespace="duration"
      :column-label="$i18n.t('Duration')"
      :text="$i18n.t('Approximate duration of a scan. User being scanned on registration are presented a progress bar for this duration, afterwards the browser refreshes until scan is complete.')"
    />

    <form-group-pre-registration namespace="pre_registration"
      :column-label="$i18n.t('Scan before registration')"
      :text="$i18n.t('If this option is enabled, the PF system will scan host before the registration.')"
    />

    <form-group-registration namespace="registration"
      :column-label="$i18n.t('Scan on registration')"
      :text="$i18n.t('If this option is enabled, the PF system will scan each host after registration is complete.')"
    />

    <form-group-post-registration namespace="post_registration"
      :column-label="$i18n.t('Scan after registration')"
      :text="$i18n.t('If this option is enabled, the PF system will scan host after on the production VLAN.')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupCategories,
  FormGroupDuration,
  FormGroupEngineIdentifier,
  FormGroupIdentifier,
  FormGroupIp,
  FormGroupOses,
  FormGroupPassword,
  FormGroupPreRegistration,
  FormGroupPort,
  FormGroupPostRegistration,
  FormGroupRegistration,
  FormGroupSiteIdentifier,
  FormGroupTemplateIdentifier,
  FormGroupUsername,
  FormGroupVerifyHostname
} from './'

const components = {
  BaseForm,

  FormGroupCategories,
  FormGroupDuration,
  FormGroupEngineIdentifier,
  FormGroupIdentifier,
  FormGroupIp,
  FormGroupOses,
  FormGroupPassword,
  FormGroupPreRegistration,
  FormGroupPort,
  FormGroupPostRegistration,
  FormGroupRegistration,
  FormGroupSiteIdentifier,
  FormGroupTemplateIdentifier,
  FormGroupUsername,
  FormGroupVerifyHostname
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-rapid7',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
