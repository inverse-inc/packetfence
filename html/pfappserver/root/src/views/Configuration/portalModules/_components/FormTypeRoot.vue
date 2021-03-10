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

    <form-group-modules namespace="modules"
      :column-label="$i18n.t('Modules')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupModules
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupModules
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-root',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

