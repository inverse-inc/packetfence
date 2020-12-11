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

    <form-group-tenant-identifier namespace="tenant_id"
      :column-label="$i18n.t('Tenant')"
    />

    <form-group-rate-limit :namespaces="['rate_limit.interval', 'rate_limit.unit']"
      :column-label="$i18n.t('Rate limit')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupPath,
  FormGroupRateLimit,
  FormGroupStatus,
  FormGroupTenantIdentifier
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupPath,
  FormGroupRateLimit,
  FormGroupStatus,
  FormGroupTenantIdentifier
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
