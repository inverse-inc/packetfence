<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Profile Name')"
    />

    <form-group-status namespace="status"
      :column-label="$i18n.t('Status')"
      :text="$i18n.t('Whether or not the policy should be enabled')"
    />

    <form-group-description namespace="description"
      :column-label="$i18n.t('Description')"
    />

    <form-group-devices-included namespace="devices_included"
      :column-label="$i18n.t('Devices Included')"
      :text="$i18n.t('The list of Fingerbank devices that will be impacted by this Network Behavior Policy. Devices of this list implicitely includes all the children of the selected devices. Leaving this empty will have all devices impacted by this policy.')"
    />

    <form-group-devices-excluded namespace="devices_excluded"
      :column-label="$i18n.t('Devices Excluded')"
      :text="$i18n.t('The list of Fingerbank devices that should not be impacted by this Network Behavior Policy. Devices of this list implicitely includes all the children of the selected devices.')"
    />

    <form-group-watch-blacklisted-ips namespace="watch_blacklisted_ips"
      :column-label="$i18n.t('Monitor for blacklisted IPs')"
      :text="$i18n.t('Whether or not the policy should check if the endpoints are communicating with blacklisted IP addresses.')"
    />

    <form-group-whitelisted-ips namespace="whitelisted_ips"
      :column-label="$i18n.t('Whitelisted IPs')"
      :text="$i18n.t('Comma delimited list of IP addresses (can be CIDR) to ignore when checking against the blacklisted IPs list.')"
    />

    <form-group-blacklisted-ip-hosts-window :namespaces="['blacklisted_ip_hosts_window.interval', 'blacklisted_ip_hosts_window.unit']"
      :column-label="$i18n.t('Blacklisted IP Hosts Window')"
      :text="$i18n.t('The window to consider when counting the amount of blacklisted IPs the endpoint has communicated with.')"
    />

    <form-group-blacklisted-ip-hosts-threshold namespace="blacklisted_ip_hosts_threshold"
      :column-label="$i18n.t('Blacklisted IPs Threshold')"
      :text="$i18n.t('If an endpoint talks with more than this amount of blacklisted IPs in the window defined above, then it triggers an event.')"
    />

    <form-group-blacklisted-ports namespace="blacklisted_ports"
      :column-label="$i18n.t('Blacklisted ports')"
      :text="$i18n.t('Which ports should be considered as vulnerable/dangerous and trigger an event. Should be a comma delimited list of ports. Also supports ranges (ex: &quot;1000-1024&quot; configures ports 1000 to 1024 inclusively). This list is for the outbound communication of the endpoint.')"
    />

    <form-group-blacklisted-ports-window :namespaces="['blacklisted_ports_window.interval', 'blacklisted_ports_window.unit']"
      :column-label="$i18n.t('Blacklisted ports window')"
      :text="$i18n.t('The window to consider when checking for blacklisted ports communication.')"
    />

    <form-group-watched-device-attributes namespace="watched_device_attributes"
      :column-label="$i18n.t('Watched Device Attributes')"
      :text="$i18n.t('Defines the attributes that should be analysed when checking against the pristine profile of the endpoint. Leaving this empty will disable the feature.')"
    />

    <form-group-device-attributes-diff-score namespace="device_attributes_diff_score"
      :column-label="$i18n.t('Device attributes minimal score')"
      :text="$i18n.t(`If an endpoint doesn't get at least this score when being matched against the pristine profile, then it triggers an event.`)"
    />

    <form-group-device-attributes-diff-threshold-overrides namespace="device_attributes_diff_threshold_overrides"
      :column-label="$i18n.t('Device Attributes weight')"
      :text="$i18n.t('Override the weight of the different attributes when matching them against the pristine profiles.')"
    />
  </base-form>
</template>
<script>
import { computed, provide, reactive, ref, toRefs, watch } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupBlacklistedIpHostsThreshold,
  FormGroupBlacklistedIpHostsWindow,
  FormGroupBlacklistedPorts,
  FormGroupBlacklistedPortsWindow,
  FormGroupDescription,
  FormGroupDeviceAttributesDiffThresholdOverrides,
  FormGroupDeviceAttributesDiffScore,
  FormGroupDevicesExcluded,
  FormGroupDevicesIncluded,
  FormGroupIdentifier,
  FormGroupStatus,
  FormGroupWatchBlacklistedIps,
  FormGroupWatchedDeviceAttributes,
  FormGroupWhitelistedIps
} from './'

const components = {
  BaseForm,

  FormGroupBlacklistedIpHostsThreshold,
  FormGroupBlacklistedIpHostsWindow,
  FormGroupBlacklistedPorts,
  FormGroupBlacklistedPortsWindow,
  FormGroupDescription,
  FormGroupDeviceAttributesDiffThresholdOverrides,
  FormGroupDeviceAttributesDiffScore,
  FormGroupDevicesExcluded,
  FormGroupDevicesIncluded,
  FormGroupIdentifier,
  FormGroupStatus,
  FormGroupWatchBlacklistedIps,
  FormGroupWatchedDeviceAttributes,
  FormGroupWhitelistedIps
}

export const props = {
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
  },
  id: {
    type: String
  }
}

export const setup = (props) => {

  const {
    id
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

  // provide a shared cache to all child components
  const sharedCache = reactive({})
  provide('sharedCache', sharedCache)

  // provide a shared uuid to all child components
  const showUuid = ref(null)
  provide('showUuid', showUuid)

  // clear shown uuid when local `id` changes
  watch(id, () => {
    showUuid.value = null
  })

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
