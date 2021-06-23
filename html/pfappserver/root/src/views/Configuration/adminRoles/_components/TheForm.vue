<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('General')" active>

        <form-group-identifier namespace="id"
          :column-label="$i18n.t('Name')"
          :disabled="!isNew && !isClone"
        />

        <form-group-description namespace="description"
          :column-label="$i18n.t('Description')"
        />

        <form-group-actions namespace="actions"
          :column-label="$i18n.t('Actions')"
          :text="$i18n.t('With no actions specified, the admin will have no roles.')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('User Options')">
        <form-group-allowed-access-levels namespace="allowed_access_levels"
          :column-label="$i18n.t('Allowed user access levels')"
          :text="$i18n.t('List of access levels available to the admin user. If none are provided then all access levels are available.')"
        />

        <form-group-allowed-roles namespace="allowed_roles"
          :column-label="$i18n.t('Allowed user roles')"
          :text="$i18n.t('List of roles available to the admin user to assign to a user. If none are provided then all roles are available.')"
        />

        <form-group-allowed-access-durations namespace="allowed_access_durations"
          :column-label="$i18n.t('Allowed user access durations')"
          :text="$i18n.t('A comma seperated list of access durations available to the admin user. If none are provided then the default access durations are used.')"
        />

        <form-group-allowed-unreg-date namespace="allowed_unreg_date"
          :column-label="$i18n.t('Maximum allowed unregistration date')"
          :text="$i18n.t('The maximum unregistration date that can be set.')"
        />

        <form-group-allowed-actions namespace="allowed_actions"
          :column-label="$i18n.t('Allowed actions')"
          :text="$i18n.t('List of actions available to the admin user. If none are provided then all actions are available.')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Node Options')">
        <form-group-allowed-node-roles namespace="allowed_node_roles"
          :column-label="$i18n.t('Allowed node roles')"
          :text="$i18n.t('List of roles available to the admin user to assign to a node. If none are provided then all roles are available.')"
        />
      </base-form-tab>
    </b-tabs>
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm,
  BaseFormTab
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupActions,
  FormGroupAllowedAccessLevels,
  FormGroupAllowedRoles,
  FormGroupAllowedAccessDurations,
  FormGroupAllowedUnregDate,
  FormGroupAllowedActions,
  FormGroupAllowedNodeRoles
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupActions,
  FormGroupAllowedAccessLevels,
  FormGroupAllowedRoles,
  FormGroupAllowedAccessDurations,
  FormGroupAllowedUnregDate,
  FormGroupAllowedActions,
  FormGroupAllowedNodeRoles
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

