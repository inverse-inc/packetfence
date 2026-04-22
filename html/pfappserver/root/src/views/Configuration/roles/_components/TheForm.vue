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

    <form-group-parent-identifier namespace="parent_id"
                                  :column-label="$i18n.t('Parent role')"
    />

    <form-group-max-nodes-per-pid namespace="max_nodes_per_pid"
                                  type="number"
                                  :column-label="$i18n.t('Max nodes per user')"
                                  :text="$i18n.t('The maximum number of nodes a user having this role can register. A number of 0 means unlimited number of devices.')"
    />

    <form-group-include-parent-acls namespace="include_parent_acls"
                                    :column-label="$i18n.t('Include Parent ACLs')"
                                    enabled-value="enabled"
                                    disabled-value="disabled"
    />

    <form-group-fingerbank-dynamic-access-list namespace="fingerbank_dynamic_access_list"
                                               :column-label="$i18n.t('Fingerbank Dynamic ACLs')"
                                               :text="$i18n.t('Use the Fingerbank dynamic ACLS')"
                                               enabled-value="enabled"
                                               disabled-value="disabled"
    />

    <form-group-acls-enabled namespace="acls_enabled"
                             :column-label="$i18n.t('Enable ACLs')"
                             :text="$i18n.t('Enable the use of ACLs defined below')"
                             enabled-value="enabled"
                             disabled-value="disabled"
    />

    <form-group-acls namespace="acls"
                     :column-label="$i18n.t('ACLs')"
                     :text="$i18n.t('Access Control Lists')"
                     rows="10"
    />

    <form-group-inherit-vlan namespace="inherit_vlan"
                             :column-label="$i18n.t('Inherit VLAN')"
                             :text="$i18n.t('Inherit VLAN from parent if none is found')"
                             enabled-value="enabled"
                             disabled-value="disabled"
    />

    <form-group-inherit-role namespace="inherit_role"
                             :column-label="$i18n.t('Inherit Role')"
                             :text="$i18n.t('Inherit Role from parent if none is found')"
                             enabled-value="enabled"
                             disabled-value="disabled"
    />

    <form-group-inherit-web-auth-url namespace="inherit_web_auth_url"
                                     :column-label="$i18n.t('Inherit Web Auth URL')"
                                     :text="$i18n.t('Inherit Web Auth URL from parent if none is found')"
                                     enabled-value="enabled"
                                     disabled-value="disabled"
    />
  </base-form>
</template>
<script>
import {computed, ref, set, watch} from '@vue/composition-api'
import apiCall from '@/utils/api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupNotes,
  FormGroupMaxNodesPerPid,
  FormGroupParentIdentifier,
  FormGroupIncludeParentAcls,
  FormGroupFingerbankDynamicAccessList,
  FormGroupAclsEnabled,
  FormGroupAcls,
  FormGroupInheritVlan,
  FormGroupInheritRole,
  FormGroupInheritWebAuthUrl
} from './'

const INHERITED_FIELDS = ['acls', 'max_nodes_per_pid']

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupNotes,
  FormGroupMaxNodesPerPid,
  FormGroupParentIdentifier,
  FormGroupIncludeParentAcls,
  FormGroupFingerbankDynamicAccessList,
  FormGroupAclsEnabled,
  FormGroupAcls,
  FormGroupInheritVlan,
  FormGroupInheritRole,
  FormGroupInheritWebAuthUrl
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

  const roles = ref([])
  const basePlaceholders = {}
  let capturedFromMeta = null

  apiCall.get('config/roles', {
    params: {
      fields: ['id', 'parent_id', ...INHERITED_FIELDS].join(','),
      limit: 1000,
      sort: 'id'
    }
  }).then(response => {
    const { data: { items = [] } = {} } = response
    roles.value = items
  }).catch(() => {})

  watch(
    [
      () => props.meta,
      () => props.form && props.form.parent_id,
      roles
    ],
    () => {
      const meta = props.meta
      if (!meta) return
      if (capturedFromMeta !== meta && INHERITED_FIELDS.some(f => meta[f])) {
        INHERITED_FIELDS.forEach(f => {
          basePlaceholders[f] = (meta[f] || {}).placeholder
        })
        capturedFromMeta = meta
      }
      const parentId = (props.form || {}).parent_id
      const parent = parentId ? roles.value.find(r => r.id === parentId) : null
      INHERITED_FIELDS.forEach(f => {
        if (!meta[f]) return
        const parentValue = parent ? parent[f] : undefined
        const nextPlaceholder = (parentValue !== undefined && parentValue !== null && parentValue !== '')
          ? parentValue
          : basePlaceholders[f]
        if (meta[f].placeholder === nextPlaceholder) return
        set(meta, f, { ...meta[f], placeholder: nextPlaceholder })
      })
    },
    { immediate: true }
  )

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
