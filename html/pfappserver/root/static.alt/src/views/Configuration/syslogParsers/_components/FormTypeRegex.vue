<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Detector')"
      :disabled="!isNew && !isClone"
    />

    <form-group-status namespace="status"
      :column-label="$i18n.t('Status')"
    />

    <form-group-path namespace="path"
      :column-label="$i18n.t('Alert pipe')"
    />

    <form-group-rules namespace="rules"
      :column-label="$i18n.t('Rules')"
    />

    <form-group-test namespace="lines"
      :column-label="$i18n.t('Sample log lines')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupPath,
  FormGroupRules,
  FormGroupStatus,
  FormGroupTest
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupPath,
  FormGroupRules,
  FormGroupStatus,
  FormGroupTest
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-regex',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
