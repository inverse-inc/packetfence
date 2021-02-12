<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('WMI Rule')"
      :disabled="!isNew && !isClone"
    />

    <form-group-on-tab namespace="on_tab"
      :column-label="$i18n.t('On node tab')"
      :text="$i18n.t('Scan this WMI element while editing a node.')"
    />

    <form-group-namespace namespace="namespace"
      :column-label="$i18n.t('Namespace')"
    />

    <form-group-request namespace="request"
      :column-label="$i18n.t('Request')"
    />

    <form-group-action namespace="action"
      :column-label="$i18n.t('Rules Actions')"
      :text="$i18n.t('Add an action based on the result of the request.')"
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
  FormGroupAction,
  FormGroupIdentifier,
  FormGroupNamespace,
  FormGroupOnTab,
  FormGroupRequest
} from './'

const components = {
  BaseForm,

  FormGroupAction,
  FormGroupIdentifier,
  FormGroupNamespace,
  FormGroupOnTab,
  FormGroupRequest
}

export const props = {
  id: {
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

