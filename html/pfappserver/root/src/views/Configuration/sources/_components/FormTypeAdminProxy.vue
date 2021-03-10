<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Name')"
      :disabled="!isNew && !isClone"
    />

    <form-group-description namespace="description"
      :column-label="$i18n.t('Description')"
    />

    <form-group-proxy-addresses namespace="proxy_addresses"
      :column-label="$i18n.t('Proxy addresses')"
      :text="$i18n.t('A comma seperated list of IP Address.')"
      :rows="5"
    />

    <form-group-user-header namespace="user_header"
      :column-label="$i18n.t('User header')"
    />

    <form-group-group-header namespace="group_header"
      :column-label="$i18n.t('Group header')"
    />

    <form-group-administration-rules namespace="administration_rules"
      :column-label="$i18n.t('Administration Rules')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupAdministrationRules,
  FormGroupDescription,
  FormGroupGroupHeader,
  FormGroupIdentifier,
  FormGroupProxyAddresses,
  FormGroupUserHeader
} from './'

const components = {
  BaseForm,

  FormGroupAdministrationRules,
  FormGroupDescription,
  FormGroupGroupHeader,
  FormGroupIdentifier,
  FormGroupProxyAddresses,
  FormGroupUserHeader
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-admin-proxy',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
