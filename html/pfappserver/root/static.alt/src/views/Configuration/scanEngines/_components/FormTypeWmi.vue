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

    <form-group-username namespace="username"
      :column-label="$i18n.t('Username')"
    />

    <form-group-domain namespace="domain"
      :column-label="$i18n.t('Domain')"
    />

    <form-group-password namespace="password"
      :column-label="$i18n.t('Password')"
    />

    <form-group-categories namespace="categories"
      :column-label="$i18n.t('Roles')"
      :text="$i18n.t('Nodes with the selected roles will be affected.')"
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

    <form-group-wmi-rules namespace="wmi_rules"
      :column-label="$i18n.t('WMI Rules')"
      :text="$i18n.t('If this option is enabled, the PF system will scan host after on the production VLAN. With no WMI rules specified, the scan engine will not be triggered.')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupCategories,
  FormGroupDomain,
  FormGroupDuration,
  FormGroupIdentifier,
  FormGroupPassword,
  FormGroupPreRegistration,
  FormGroupPostRegistration,
  FormGroupRegistration,
  FormGroupUsername,
  FormGroupWmiRules
} from './'

const components = {
  BaseForm,

  FormGroupCategories,
  FormGroupDomain,
  FormGroupDuration,
  FormGroupIdentifier,
  FormGroupPassword,
  FormGroupPreRegistration,
  FormGroupPostRegistration,
  FormGroupRegistration,
  FormGroupUsername,
  FormGroupWmiRules
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-wmi',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
