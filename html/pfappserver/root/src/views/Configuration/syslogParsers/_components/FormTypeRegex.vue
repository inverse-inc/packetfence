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
                       :column-label="$i18n.t('Enabled')"
                       enabled-value="enabled"
                       disabled-value="disabled"
    />

    <form-group-path namespace="path"
                     :column-label="$i18n.t('Alert pipe')"
    />

    <form-group-rate-limit namespace="rate_limit"
                           :column-label="$i18n.t('Rate limit')"
    />

    <form-group-rules namespace="rules"
                      :column-label="$i18n.t('Rules')"
    />

    <form-group-test namespace="lines"
                     :column-label="$i18n.t('Sample Log Lines')"
    />
  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupPath,
  FormGroupRateLimit,
  FormGroupRules,
  FormGroupStatus,
  FormGroupTest
} from './'
import {useForm as setup, useFormProps as props} from '../_composables/useForm'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupPath,
  FormGroupRateLimit,
  FormGroupRules,
  FormGroupStatus,
  FormGroupTest
}

// @vue/component
export default {
  name: 'form-type-regex',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
