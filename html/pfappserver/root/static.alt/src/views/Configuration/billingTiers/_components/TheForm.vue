<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Billing Tier')"
      :disabled="!isNew && !isClone"
    />

    <form-group-name namespace="name"
      :column-label="$i18n.t('Name')"
    />

    <form-group-description namespace="description"
      :column-label="$i18n.t('Description')"
    />

    <form-group-price namespace="price"
      :column-label="$i18n.t('Price')"
    />

    <form-group-role namespace="role"
      :column-label="$i18n.t('Role')"
    />

    <form-group-access-duration :namespaces="['access_duration.interval', 'access_duration.unit']"
      :column-label="$i18n.t('Access Duration')"
      :text="$i18n.t('The access duration of the devices that use this tier.')"
    />

    <form-group-use-time-balance namespace="use_time_balance"
      :column-label="$i18n.t('Use Time Balance')"
      :text="$i18n.t('Check this box to have the access duration be a real time usage.<br/>This requires a working accounting configuration.')"
    />
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupName,
  FormGroupDescription,
  FormGroupPrice,
  FormGroupRole,
  FormGroupAccessDuration,
  FormGroupUseTimeBalance
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupName,
  FormGroupDescription,
  FormGroupPrice,
  FormGroupRole,
  FormGroupAccessDuration,
  FormGroupUseTimeBalance
}

export const props = {
  id: {
    type: String
  },
  tenantId: {
    type: String
  },
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
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

