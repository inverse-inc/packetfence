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
          :column-label="$i18n.t('Profile Name')"
          :disabled="!isNew && !isClone"
        />

        <form-group-description namespace="description"
          :column-label="$i18n.t('Description')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Status Page')">
        <form-group-roles-allowed-to-unregister namespace="roles_allowed_to_unregister"
          :column-label="$i18n.t('Allowed roles')"
          :text="$i18n.t('The list of roles that are allowed to unregister devices using the self-service portal. Leaving this empty will allow all users to unregister their devices.')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Self Service')">
        <form-group-device-registration-roles namespace="device_registration_roles"
          :column-label="$i18n.t('Role to assign')"
          :text="$i18n.t('The role to assign to devices registered from the self-service portal. If none is specified, the role of the registrant is used. If multiples are defined then the user will have to choose.')"
        />

        <form-group-device-registration-access-duration :namespaces="['device_registration_access_duration.interval', 'device_registration_access_duration.unit']"
          :column-label="$i18n.t('Access duration to assign')"
          :text="$i18n.t('The access duration to assign to devices registered from the self-service portal. If zero is specified, the access duration of the registrant is used.')"
        />

        <form-group-device-registration-allowed-devices namespace="device_registration_allowed_devices"
          :column-label="$i18n.t('Allowed OS')"
          :text="$i18n.t('List of OS which will be allowed to be register via the self service portal.')"
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
  FormGroupDeviceRegistrationAccessDuration,
  FormGroupDeviceRegistrationAllowedDevices,
  FormGroupDeviceRegistrationRoles,
  FormGroupRolesAllowedToUnregister
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupDeviceRegistrationAccessDuration,
  FormGroupDeviceRegistrationAllowedDevices,
  FormGroupDeviceRegistrationRoles,
  FormGroupRolesAllowedToUnregister
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

