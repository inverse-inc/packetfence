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

    <form-group-proto namespace="proto"
                      :column-label="$i18n.t('Protocol')"
    />

    <form-group-host namespace="host"
                     :column-label="$i18n.t('Host')"
    />

    <form-group-port namespace="port"
                     :column-label="$i18n.t('Port')"
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
import {
  FormGroupAllLogs,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupLogs,
  FormGroupPort,
  FormGroupProto
} from './'
import {useForm as setup, useFormProps as props} from '../_composables/useForm'

const components = {
  BaseForm,

  FormGroupAllLogs,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupLogs,
  FormGroupPort,
  FormGroupProto
}

// @vue/component
export default {
  name: 'form-type-server',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
