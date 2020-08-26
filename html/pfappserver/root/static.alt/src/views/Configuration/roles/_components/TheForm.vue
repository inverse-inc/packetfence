<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier
      namespace="id"
      :disabled="!isNew && !isClone"
    />

    <form-group-notes
      namespace="notes"
    />

    <form-group-max-nodes-per-pid
      namespace="max_nodes_per_pid"
    />

    <pre>{{ form }}</pre>
    <pre>{{ meta }}</pre>
    <!--
    <pre>{{ schema }}</pre>
    -->

  </base-form>
</template>
<script>
import {
  BaseForm
} from '@/components/new/'
import {
  schema,
  FormGroupIdentifier,
  FormGroupMaxNodesPerPid,
  FormGroupNotes
} from '../'

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  schema: {
    type: Object,
    default: () => (schema)
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

export const setup = (/*props, context*/) => {
  return {}
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

