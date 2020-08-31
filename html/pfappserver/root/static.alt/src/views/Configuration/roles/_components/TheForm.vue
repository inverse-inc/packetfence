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

    <form-group-notes namespace="notes"
      :column-label="$i18n.t('Description')"
    />

    <form-group-max-nodes-per-pid namespace="max_nodes_per_pid"
      type="number"
      :column-label="$i18n.t('Max nodes per user')"
      :text="$i18n.t('The maximum number of nodes a user having this role can register. A number of 0 means unlimited number of devices.')"
    />

  </base-form>
</template>
<script>
import { computed, ref, toRefs, unref, watch } from '@vue/composition-api'

import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupMaxNodesPerPid,
  FormGroupNotes
} from './'

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
  components: {
    BaseForm,
    FormGroupIdentifier,
    FormGroupMaxNodesPerPid,
    FormGroupNotes
  },
  props,
  setup
}
</script>

