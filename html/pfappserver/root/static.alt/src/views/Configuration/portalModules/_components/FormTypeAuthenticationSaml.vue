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

    <form-group-with-aup namespace="with_aup"
      :column-label="$i18n.t('Require AUP')"
      :text="$i18n.t('Require the user to accept the AUP')"
    />

    <form-group-aup-template namespace="aup_template"
      :column-label="$i18n.t('AUP template')"
      :text="$i18n.t('The template to use for the Acceptable Use Policy')"
    />

    <form-group-landing-template namespace="landing_template"
      :column-label="$i18n.t('Landing template')"
      :text="$i18n.t('The template to use for the signup')"
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
  FormGroupAupTemplate,
  FormGroupDescription,
  FormGroupLandingTemplate,
  FormGroupSourceIdentifier,
  FormGroupWithAup
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupActions,
  FormGroupAupTemplate,
  FormGroupDescription,
  FormGroupLandingTemplate,
  FormGroupSourceIdentifier,
  FormGroupWithAup
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-authentication-saml',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

