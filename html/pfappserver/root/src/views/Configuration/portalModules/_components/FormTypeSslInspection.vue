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

    <form-group-description namespace="description"
      :column-label="$i18n.t('Description')"
      :text="$i18n.t('The description that will be displayed to users')"
    />

    <form-group-ssl-path namespace="ssl_path"
      :column-label="$i18n.t('SSL Certificate URL')"
      :text="$i18n.t('URL of the SSL certificate in X509 Base64 format.')"
    />

    <form-group-ssl-mobileconfig-path namespace="ssl_mobileconfig_path"
      :column-label="$i18n.t('SSL iOS profile URL')"
      :text="$i18n.t('URL of an iOS mobileconfig profile to install the certificate.')"
    />

    <form-group-skipable namespace="skipable"
      :column-label="$i18n.t('Skipable')"
      :text="$i18n.t('Whether or not, this message can be skipped')"
    />

    <form-group-actions namespace="actions"
      :column-label="$i18n.t('Actions')"
      :text="$i18n.t('If none are specified, the default ones of the module will be used.')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupActions,
  FormGroupDescription,
  FormGroupSkipable,
  FormGroupSslMobileconfigPath,
  FormGroupSslPath
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupActions,
  FormGroupDescription,
  FormGroupSkipable,
  FormGroupSslMobileconfigPath,
  FormGroupSslPath
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-ssl-inspection',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

