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

    <form-group-pid-field namespace="pid_field"
      :column-label="$i18n.t('PID field')"
      :text="$i18n.t('Which field should be used as the PID.')"
    />

    <form-group-custom-fields namespace="custom_fields"
      :column-label="$i18n.t('Mandatory fields')"
      :text="$i18n.t('Additional fields that should be required for registration')"
    />

    <form-group-fields-to-save namespace="fields_to_save"
      :column-label="$i18n.t('Fields to save')"
      :text="$i18n.t('These fields will be saved through the registration process')"
    />

    <form-group-with-aup namespace="with_aup"
      :column-label="$i18n.t('Require AUP')"
      :text="$i18n.t('Require the user to accept the AUP')"
    />

    <form-group-aup-template namespace="aup_template"
      :column-label="$i18n.t('AUP template')"
      :text="$i18n.t('The template to use for the Acceptable Use Policy')"
    />

    <form-group-signup-template namespace="signup_template"
      :column-label="$i18n.t('Signup template')"
      :text="$i18n.t('The template to use for the signup')"
    />

    <form-group-multi-source-identifiers namespace="multi_source_ids"
      :column-label="$i18n.t('Authentication Sources')"
      :text="$i18n.t('The sources to use in the module. If no sources are specified, all the sources of the connection profile will be used.')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupAupTemplate,
  FormGroupCustomFields,
  FormGroupDescription,
  FormGroupFieldsToSave,
  FormGroupMultiSourceIdentifiers,
  FormGroupPidField,
  FormGroupSignupTemplate,
  FormGroupWithAup
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupAupTemplate,
  FormGroupCustomFields,
  FormGroupDescription,
  FormGroupFieldsToSave,
  FormGroupMultiSourceIdentifiers,
  FormGroupPidField,
  FormGroupSignupTemplate,
  FormGroupWithAup
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-authentication-billing',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

