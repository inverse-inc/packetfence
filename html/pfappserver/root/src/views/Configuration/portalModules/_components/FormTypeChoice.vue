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

    <form-group-show-first-module-on-default namespace="show_first_module_on_default"
      :column-label="$i18n.t('Show first module when none is selected')"
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
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupActions,
  FormGroupDescription,
  FormGroupModules,
  FormGroupShowFirstModuleOnDefault,
  FormGroupTemplate,
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupActions,
  FormGroupDescription,
  FormGroupModules,
  FormGroupShowFirstModuleOnDefault,
  FormGroupTemplate,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-choice',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
