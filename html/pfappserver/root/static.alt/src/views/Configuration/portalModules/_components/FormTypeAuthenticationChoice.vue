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

    <form-group-actions namespace="actions"
      :column-label="$i18n.t('Actions')"
      :text="$i18n.t('If none are specified, the default ones of the module will be used.')"
    />

    <form-group-modules namespace="modules"
      :column-label="$i18n.t('Modules')"
    />

    <form-group-multi-source-identifiers namespace="multi_source_ids"
      :column-label="$i18n.t('Authentication Sources')"
      :text="$i18n.t('The sources to use in the module. If no sources are specified, all the sources of the connection profile will be used.')"
    />

    <form-group-multi-source-object-classes namespace="multi_source_object_classes"
      :column-label="$i18n.t('Sources by Class')"
      :text="$i18n.t('The sources inheriting from these classes and part of the connection profile will be added to the available sources')"
    />

    <form-group-multi-source-types namespace="multi_source_types"
      :column-label="$i18n.t('Sources by type')"
      :text="$i18n.t('The sources of these types and part of the connection profile will be added to the available sources')"
    />

    <form-group-multi-source-auth-classes namespace="multi_source_auth_classes"
      :column-label="$i18n.t('Sources by Auth Class')"
      :text="$i18n.t('The sources of these authentication classes and part of the connection profile will be added to the available sources')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupActions,
  FormGroupCustomFields,
  FormGroupDescription,
  FormGroupFieldsToSave,
  FormGroupModules,
  FormGroupMultiSourceIdentifiers,
  FormGroupMultiSourceAuthClasses,
  FormGroupMultiSourceObjectClasses,
  FormGroupMultiSourceTypes,
  FormGroupTemplate
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupActions,
  FormGroupCustomFields,
  FormGroupDescription,
  FormGroupFieldsToSave,
  FormGroupModules,
  FormGroupMultiSourceIdentifiers,
  FormGroupMultiSourceAuthClasses,
  FormGroupMultiSourceObjectClasses,
  FormGroupMultiSourceTypes,
  FormGroupTemplate
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-authentication-choice',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

