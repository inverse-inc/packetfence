<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
                           :column-label="$i18n.t('Syslog Name')"
                           :disabled="!isNew && !isClone"
    />

    <form-group-all-logs namespace="all_logs"
                         :column-label="$i18n.t('All logs')"
                         enabled-value="enabled"
                         disabled-value="disabled"
    />

    <form-group-logs v-show="form.all_logs === 'disabled'"
                     namespace="logs"
                     :column-label="$i18n.t('Logs')"
    />
  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
import {FormGroupAllLogs, FormGroupIdentifier, FormGroupLogs} from './'
import {useForm as setup, useFormProps as props} from '../_composables/useForm'

const components = {
  BaseForm,

  FormGroupAllLogs,
  FormGroupIdentifier,
  FormGroupLogs
}

// @vue/component
export default {
  name: 'form-type-file',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
