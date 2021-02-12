<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-lease-length namespace="lease_length"
      :column-label="$i18n.t('Parking lease length')"
      :text="$i18n.t('Lease length (in seconds) when a device is in parking.')"
    />

    <form-group-threshold namespace="threshold"
      :column-label="$i18n.t('Parking threshold')"
      :text="$i18n.t('The threshold (in seconds) after which a device will be placed in parking. A value of 0 deactivates the parking detection. The detection works by looking at the time in seconds a device has been in the registration role and comparing it with this threshold.')"
    />

    <form-group-place-in-dhcp-parking-group namespace="place_in_dhcp_parking_group"
      :column-label="$i18n.t('Place in DHCP parking group')"
      :text="$i18n.t('Place the device in the DHCP parking group when it is detected doing parking.')"
    />

    <form-group-show-parking-portal namespace="show_parking_portal"
      :column-label="$i18n.t('Show parking portal')"
      :text="$i18n.t('Show the parking portal to the device instead of the usual portal.')"
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
  FormGroupLeaseLength,
  FormGroupThreshold,
  FormGroupPlaceInDhcpParkingGroup,
  FormGroupShowParkingPortal
} from './'

const components = {
  BaseForm,

  FormGroupLeaseLength,
  FormGroupThreshold,
  FormGroupPlaceInDhcpParkingGroup,
  FormGroupShowParkingPortal
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

