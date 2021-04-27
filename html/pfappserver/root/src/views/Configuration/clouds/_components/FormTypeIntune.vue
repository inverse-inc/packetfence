<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Name')"
      :disabled="!isNew && !isClone"
    />

    <form-group-tenant-id namespace="tenant_id"
      :column-label="$i18n.t('The tenant ID of the intune service')"
      :text="$i18n.t('Define the tenant ID defined in the Azure admin portal.')"
    />

    <form-group-client-id namespace="client_id"
      :column-label="$i18n.t('The client ID of the intune service')"
      :text="$i18n.t('Define the client ID defined in the Azure admin portal.')"
    />

    <form-group-client-secret namespace="client_secret"
      :column-label="$i18n.t('The client secret of the intune service')"
      :text="$i18n.t('Define the client secret defined in the Azure admin portal.')"
    />

  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupTenantId,
  FormGroupClientId,
  FormGroupClientSecret,
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupTenantId,
  FormGroupClientId,
  FormGroupClientSecret,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-intune',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
