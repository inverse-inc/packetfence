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

    <form-group-source-identifier namespace="source_id"
      :column-label="$i18n.t('Authentication Source')"
      :text="$i18n.t('The source to use in the module. If no source is specified, all the sources of the connection profile will be used.')"
    />

    <form-group-custom-fields namespace="custom_fields"
      :column-label="$i18n.t('Mandatory fields')"
      :text="$i18n.t('Additional fields that should be required for registration')"
    />

    <form-group-fields-to-save namespace="fields_to_save"
      :column-label="$i18n.t('Fields to save')"
      :text="$i18n.t('These fields will be saved through the registration process')"
    />

    <form-group-template namespace="template"
      :column-label="$i18n.t('Template')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupCustomFields,
  FormGroupDescription,
  FormGroupFieldsToSave,
  FormGroupSourceIdentifier,
  FormGroupTemplate
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupCustomFields,
  FormGroupDescription,
  FormGroupFieldsToSave,
  FormGroupSourceIdentifier,
  FormGroupTemplate
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-authentication-blackhole',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
