<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-status namespace="status"
                       :column-label="$i18n.t('Enable')"
                       :text="$i18n.t('Enable an external server for proxysql.')"
                       enabled-value="enabled"
                       disabled-value="disabled"
    />

    <form-group-cacert namespace="cacert"
                       :column-label="$i18n.t('CA Certificate')"
                       :text="$i18n.t('CA Certificate')"
    />

    <form-group-backend namespace="backend"
                        :column-label="$i18n.t('Backend')"
                        :text="$i18n.t('Backend Host')"
    />
    <form-group-scheduler namespace="scheduler"
                       :column-label="$i18n.t('Use PXC Scheduler')"
                       :text="$i18n.t('Use the PXC Scheduler handler to monitor cluster availability. Disabled by default.')"
                       enabled-value="pxc_scheduler"
                       disabled-value="default"
    />

  </base-form>
</template>
<script>
import {computed} from '@vue/composition-api'
import {BaseForm} from '@/components/new/'
import schemaFn from '../schema'
import {FormGroupBackend, FormGroupCacert, FormGroupStatus, FormGroupScheduler} from './'

const components = {
  BaseForm,

  FormGroupCacert,
  FormGroupBackend,
  FormGroupStatus,
  FormGroupScheduler,
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props) => {

  const schema = computed(() => schemaFn(props))

  return {
    schema
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

