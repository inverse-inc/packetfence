<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Identifier')"
      :disabled="!isNew && !isClone"
    />

    <form-group-description namespace="description"
      :column-label="$i18n.t('Description')"
    />

    <form-group-host namespace="host"
      :column-label="$i18n.t('Host')"
    />

    <form-group-port namespace="port"
      :column-label="$i18n.t('Port')"
    />

    <form-group-facility namespace="facility"
      :column-label="$i18n.t('Facility')"
    />

    <form-group-namespaces namespace="namespaces"
      :column-label="$i18n.t('Namespaces')"
    />

    <form-group-priority namespace="priority"
      :column-label="$i18n.t('Priority')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupHost,
  FormGroupPort,
  FormGroupFacility,
  FormGroupNamespaces,
  FormGroupPriority
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupHost,
  FormGroupPort,
  FormGroupFacility,
  FormGroupNamespaces,
  FormGroupPriority,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-generic',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
