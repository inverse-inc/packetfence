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

    <form-group-path namespace="path"
      :column-label="$i18n.t('Htpasswd File Path')"
      :title="$i18n.t('Upload Htpasswd File')"
    />

    <form-group-realms namespace="realms"
      :column-label="$i18n.t('Associated Realms')"
      :text="$i18n.t('Realms that will be associated with this source.')"
    />

    <form-group-authentication-rules namespace="authentication_rules"
      :column-label="$i18n.t('Authentication Rules')"
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
  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupIdentifier,
  FormGroupPath,
  FormGroupRealms,
} from './'

const components = {
  BaseForm,

  FormGroupAdministrationRules,
  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupIdentifier,
  FormGroupPath,
  FormGroupRealms,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-htpasswd',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
