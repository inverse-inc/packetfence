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

    <form-group-admin-role namespace="admin_role"
      :column-label="$i18n.t('Admin Roles')"
      :text="$i18n.t('Which roles should have access to this module to select the role')"
    />

    <form-group-list-role namespace="list_role"
      :column-label="$i18n.t('Roles')"
      :text="$i18n.t('Which roles can be select')"
    />

    <form-group-template namespace="template"
      :column-label="$i18n.t('Template')"
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
  FormGroupAdminRole,
  FormGroupDescription,
  FormGroupListRole,
  FormGroupTemplate
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupActions,
  FormGroupAdminRole,
  FormGroupDescription,
  FormGroupListRole,
  FormGroupTemplate
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-select-role',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

