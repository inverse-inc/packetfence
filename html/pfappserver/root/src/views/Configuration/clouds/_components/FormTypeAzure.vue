<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Hostname or IP Address')"
      :disabled="!isNew && !isClone"
    />

    <form-group-username namespace="username"
      :column-label="$i18n.t('Username')"
    />

    <form-group-password namespace="password"
      :column-label="$i18n.t('Secret or Key')"
    />

    <form-group-port namespace="port"
      :column-label="$i18n.t('Port of the service')"
      :text="$i18n.t('If you use an alternative port, please specify.')"
    />

  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupPassword,
  FormGroupPort,
  FormGroupUsername,
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupPassword,
  FormGroupPort,
  FormGroupUsername,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-azure',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
