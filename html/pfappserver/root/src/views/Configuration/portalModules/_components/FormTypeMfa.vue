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
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupActions,
  FormGroupDescription,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-mfa',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

