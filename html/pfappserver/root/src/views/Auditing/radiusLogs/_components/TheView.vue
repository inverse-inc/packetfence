<template>
  <b-form @submit.prevent ref="rootRef">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="goToCollection" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('RADIUS Audit Log Entry')}} <strong v-text="id"></strong></h4>
      </b-card-header>
      <b-tabs ref="tabs" v-model="tabIndex" card>

        <b-tab title="RADIUS">
          <base-form-group :column-label="$t('Request Time')">{{ item.request_time }}</base-form-group>
          <base-form-group :column-label="$t('RADIUS Request')"><div class="text-pre">{{ item.radius_request }}</div></base-form-group>
          <base-form-group :column-label="$t('RADIUS Reply')"><div class="text-pre">{{ item.radius_reply }}</div></base-form-group>
        </b-tab>

        <b-tab title="Node Information">
          <template v-slot:title>
            {{ $t('Node Information') }}
          </template>
          <base-form-group :column-label="$t('MAC Address')"><mac>{{ item.mac }}</mac></base-form-group>
          <base-form-group :column-label="$t('Auth Status')">{{ item.auth_status }}</base-form-group>
          <base-form-group :column-label="$t('Auth Type')">{{ item.auth_type }}</base-form-group>
          <base-form-group :column-label="$t('Auto Registration')">
            <div v-if="item.auto_reg === '1'">{{ $t('Yes') }}</div>
            <div v-else-if="item.auto_reg === '0'">{{ $t('No') }}</div>
            <div v-else class="text-muted">{{ $t('Unknown') }}</div>
          </base-form-group>
          <base-form-group :column-label="$t('Calling Station Identifier')"><mac>{{ item.calling_station_id }}</mac></base-form-group>
          <base-form-group :column-label="$t('Computer Name')">{{ item.computer_name }}</base-form-group>
          <base-form-group :column-label="$t('EAP Type')">{{ item.eap_type }}</base-form-group>
          <base-form-group :column-label="$t('Event Type')">{{ item.event_type }}</base-form-group>
          <base-form-group :column-label="$t('IP Address')">{{ item.ip }}</base-form-group>
          <base-form-group :column-label="$t('Is a Phone')">
            <div v-if="item.is_phone === '1'">{{ $t('Yes') }}</div>
            <div v-else-if="item.is_phone === '0'">{{ $t('No') }}</div>
            <div v-else class="text-muted">{{ $t('Unknown') }}</div>
          </base-form-group>
          <base-form-group :column-label="$t('Created at')">{{ item.created_at }}</base-form-group>
          <base-form-group :column-label="$t('Node Status')">{{ item.node_status }}</base-form-group>
          <base-form-group :column-label="$t('Domain')">{{ item.pf_domain }}</base-form-group>
          <base-form-group :column-label="$t('Profile')">{{ item.profile }}</base-form-group>
          <base-form-group :column-label="$t('Realm')">{{ item.realm }}</base-form-group>
          <base-form-group :column-label="$t('Reason')">{{ item.reason }}</base-form-group>
          <base-form-group :column-label="$t('Role')">{{ item.role }}</base-form-group>
          <base-form-group :column-label="$t('Source')">{{ item.source }}</base-form-group>
          <base-form-group :column-label="$t('Stripped User Name')">{{ item.stripped_user_name }}</base-form-group>
          <base-form-group :column-label="$t('User Name')">{{ item.user_name }}</base-form-group>
          <base-form-group :column-label="$t('Unique Identifier')">{{ item.uuid }}</base-form-group>
        </b-tab>

        <b-tab title="Switch Information">
          <template v-slot:title>
            {{ $t('Switch Information') }}
          </template>
          <base-form-group :column-label="$t('Switch Identifier')">{{ item.switch_id }}</base-form-group>
          <base-form-group :column-label="$t('Switch MAC')">{{ item.switch_mac }}</base-form-group>
          <base-form-group :column-label="$t('Switch IP Address')">{{ item.switch_ip_address }}</base-form-group>
          <base-form-group :column-label="$t('Called Station Identifier')">{{ item.called_station_id }}</base-form-group>
          <base-form-group :column-label="$t('Connection Type')">{{ item.connection_type }}</base-form-group>
          <base-form-group :column-label="$t('IfIndex')">{{ item.ifindex }}</base-form-group>
          <base-form-group :column-label="$t('NAS Identifier')">{{ item.nas_identifier }}</base-form-group>
          <base-form-group :column-label="$t('NAS IP Address')">{{ item.nas_ip_address }}</base-form-group>
          <base-form-group :column-label="$t('NAS Port')">{{ item.nas_port }}</base-form-group>
          <base-form-group :column-label="$t('NAS Port Identifer')">{{ item.nas_port_id }}</base-form-group>
          <base-form-group :column-label="$t('NAS Port Type')">{{ item.nas_port_type }}</base-form-group>
          <base-form-group :column-label="$t('RADIUS Source IP Address')">{{ item.radius_source_ip_address }}</base-form-group>
          <base-form-group :column-label="$t('Wi-Fi Network SSID')">{{ item.ssid }}</base-form-group>
        </b-tab>

      </b-tabs>
    </b-card>
  </b-form>
</template>

<script>
import {
  BaseFormGroup
} from '@/components/new/'

const components = {
  BaseFormGroup
}

const props = {
  id: {
    type: String
  }
}

import { ref , toRefs, watch } from '@vue/composition-api'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import useEventJail from '@/composables/useEventJail'
import { useRouter } from '../_router'

const formatRadius = string => {
  if (string)
    return string.replace(/, /g, '\n')
}

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $router, $store } = {} } = context

  const {
    goToCollection
  } = useRouter($router)

  const tabIndex = ref(0)

  // template refs
  const rootRef = ref(null)
  useEventJail(rootRef)
  const escapeKey = useEventEscapeKey(rootRef)
  watch(escapeKey, () => goToCollection())

  const item = ref({})
  $store.dispatch(`$_radius_logs/getItem`, id.value).then(_item => {
    const { radius_request = '', radius_reply = '', ...rest } = _item
    item.value = { radius_request: formatRadius(radius_request), radius_reply: formatRadius(radius_reply), ...rest }
  })

  return {
    rootRef,
    tabIndex,
    item,
    goToCollection
  }
}

export default {
  name: 'the-view',
  components,
  props,
  setup
}
</script>
