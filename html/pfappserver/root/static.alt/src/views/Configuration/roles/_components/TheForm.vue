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

    <form-group-parent namespace="parent"
      :column-label="$i18n.t('Parent role')"
    />

    <form-group-max-nodes-per-pid namespace="max_nodes_per_pid"
      type="number"
      :column-label="$i18n.t('Max nodes per user')"
      :text="$i18n.t('The maximum number of nodes a user having this role can register. A number of 0 means unlimited number of devices.')"
    />

    <form-group-include-parent-acls namespace="include_parent_acls"
      :column-label="$i18n.t('Include Parent ACLs')"
    />

    <form-group-fingerbank-dynamic-access-list namespace="fingerbank_dynamic_access_list"
      :column-label="$i18n.t('Fingerbank Dynamic ACLs')"
      :text="$i18n.t('Use the Fingerbank dynamic ACLS')"
    />

    <form-group-acls namespace="acls"
      :column-label="$i18n.t('ACLs')"
      :text="$i18n.t('Access Control Lists')"
    />

    <form-group-inherit-vlan namespace="inherit_vlan"
      :column-label="$i18n.t('Inherit VLAN')"
      :text="$i18n.t('Inherit VLAN from parent if none is found')"
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
  FormGroupNotes,
  FormGroupMaxNodesPerPid,
  FormGroupParent,
  FormGroupIncludeParentAcls,
  FormGroupFingerbankDynamicAccessList,
  FormGroupAcls,
  FormGroupInheritVlan
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupNotes,
  FormGroupMaxNodesPerPid,
  FormGroupParent,
  FormGroupIncludeParentAcls,
  FormGroupFingerbankDynamicAccessList,
  FormGroupAcls,
  FormGroupInheritVlan
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
