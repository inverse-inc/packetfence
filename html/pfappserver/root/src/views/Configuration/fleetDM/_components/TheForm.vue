<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-fleetdm-host namespace="host"
                             :column-label="$i18n.t('FleetDM Host')"
                             :text="$i18n.t('FleetDM API Host.')"
    />

    <form-group-fleetdm-email namespace="email"
                              :column-label="$i18n.t('Email')"
                              :text="$i18n.t('Email / username for making fleetDM API calls.')"
    />

    <form-group-fleetdm-password namespace="password"
                                 :column-label="$i18n.t('Password')"
                                 :text="$i18n.t('Password for making fleetDM API calls.')"
    />

    <form-group-fleetdm-token namespace="token"
                              :column-label="$i18n.t('FleetDM API Token')"
                              :text="$i18n.t('Token used for making FleetDM API calls.')"
    />

  </base-form>
</template>
<script>
import {computed} from '@vue/composition-api'
import {BaseForm} from '@/components/new/'
import schemaFn from '../schema'
import {FormGroupFleetdmEmail, FormGroupFleetdmHost, FormGroupFleetdmPassword, FormGroupFleetdmToken,} from './'

const components = {
  BaseForm,

  FormGroupFleetdmHost,
  FormGroupFleetdmEmail,
  FormGroupFleetdmPassword,
  FormGroupFleetdmToken,
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

