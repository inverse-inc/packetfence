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

    <form-group-message namespace="message"
      :column-label="$i18n.t('Message')"
      :text="$i18n.t('The message that will be displayed to the user. Use with caution as the HTML contained in this field will NOT be escaped.')"
    />

    <form-group-template namespace="template"
      :column-label="$i18n.t('Template')"
    />

    <form-group-skipable namespace="skipable"
      :column-label="$i18n.t('Skipable')"
      :text="$i18n.t('Whether or not, this message can be skipped')"
    />

    <form-group-with-layout namespace="with_layout"
      :column-label="$i18n.t('Render portal layout')"
      :text="$i18n.t('Enabled will render with the portal layout')"
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
  FormGroupMessage,
  FormGroupSkipable,
  FormGroupTemplate,
  FormGroupWithLayout
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupActions,
  FormGroupDescription,
  FormGroupMessage,
  FormGroupSkipable,
  FormGroupTemplate,
  FormGroupWithLayout
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-message',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

