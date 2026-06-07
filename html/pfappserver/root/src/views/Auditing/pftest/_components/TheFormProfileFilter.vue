<template>
  <b-form @submit.prevent="onSubmit" class="p-3">
    <b-row class="mb-3">
      <b-col md="4">
        <small>{{ $t('MAC address') }}</small>
        <b-form-input v-model="mac" placeholder="aa:bb:cc:dd:ee:ff" />
      </b-col>
    </b-row>
    <small class="font-weight-bold">{{ $t('Attributes') }}</small>
    <p class="text-muted small mb-2">
      {{ $t('Simulate the node\'s last connection state. The matching connection profile is found by evaluating its filter rules against these attributes.') }}
    </p>
    <b-row v-for="(pair, idx) in pairs" :key="idx" class="mb-2 align-items-center">
      <b-col md="4">
        <multiselect v-model="pair.attr"
          :options="attributeOptions"
          track-by="value" label="value"
          :placeholder="$t('Pick attribute...')"
          :allow-empty="true"
          :taggable="true" @tag="newTag => pair.attr = { value: newTag, text: $t('custom') }">
          <template #option="{ option }">
            <strong>{{ option.value }}</strong>
            <span class="text-muted ml-2">{{ option.text }}</span>
          </template>
          <template #singleLabel="{ option }">
            <span class="text-monospace">{{ option.value }}</span>
          </template>
        </multiselect>
      </b-col>
      <b-col md="6">
        <b-form-input v-model="pair.value" :placeholder="placeholderFor(pair.attr)" />
      </b-col>
      <b-col md="2">
        <b-button variant="link" size="sm" class="text-danger" @click="removePair(idx)" v-if="pairs.length > 1">
          <icon name="times" />
        </b-button>
      </b-col>
    </b-row>
    <b-button variant="link" size="sm" class="pl-0" @click="addPair">
      <icon name="plus" class="mr-1" />{{ $t('Add attribute') }}
    </b-button>
    <div class="mt-3">
      <b-button type="submit" variant="primary" :disabled="isLoading || !mac">
        <icon v-if="isLoading" name="circle-notch" spin class="mr-1" />
        <icon v-else name="play" class="mr-1" />
        {{ $t('Test profile filter') }}
      </b-button>
    </div>
  </b-form>
</template>

<script>
import { ref } from '@vue/composition-api'
import Multiselect from 'vue-multiselect'

const components = { Multiselect }
const props = { isLoading: { type: Boolean, default: false } }

// Keep in sync with %PROFILE_FILTER_TYPE_TO_CONDITION_TYPE in
// lib/pf/factory/condition/profile.pm — these are the keys evaluated by
// connection-profile filter rules. Other keys still work but won't drive
// profile matching, so they're hidden from the dropdown.
const KNOWN_ATTRIBUTES = [
  { value: 'last_ssid',                text: 'last SSID seen on the node' },
  { value: 'last_switch',              text: 'switch identifier (IP/MAC/IfDesc)' },
  { value: 'last_switch_mac',          text: 'switch MAC' },
  { value: 'last_port',                text: 'switch port' },
  { value: 'last_vlan',                text: 'VLAN tag' },
  { value: 'last_ip',                  text: 'IPv4 address' },
  { value: 'last_connection_type',     text: 'Wired-802.1X, Wireless-MAC-Auth, ...' },
  { value: 'last_connection_sub_type', text: 'EAP method, etc.' },
  { value: 'last_uri',                 text: 'captive portal URI' },
  { value: 'category',                 text: 'node role / category' },
  { value: 'realm',                    text: 'RADIUS realm' },
  { value: 'fqdn',                     text: 'fully-qualified hostname' }
]

const PLACEHOLDERS = {
  last_ssid:                'corporate-wifi',
  last_switch:              '10.0.0.1',
  last_switch_mac:          '00:11:22:33:44:55',
  last_port:                'GigabitEthernet0/1',
  last_vlan:                '10',
  last_ip:                  '192.168.1.50',
  last_connection_type:     'Wireless-802.1X',
  last_connection_sub_type: 'EAP-TLS',
  category:                 'staff'
}

const setup = (props, context) => {
  const mac = ref('')
  const pairs = ref([{ attr: null, value: '' }])

  const attributeOptions = KNOWN_ATTRIBUTES

  const placeholderFor = attr => (attr && PLACEHOLDERS[attr.value]) || 'value'

  const addPair = () => pairs.value.push({ attr: null, value: '' })
  const removePair = idx => pairs.value.splice(idx, 1)

  const onSubmit = () => {
    const params = {}
    for (const pair of pairs.value) {
      if (pair.attr && pair.attr.value && pair.value !== '') {
        params[pair.attr.value] = pair.value
      }
    }
    context.emit('submit', { mac: mac.value, params })
  }
  return { mac, pairs, attributeOptions, placeholderFor, addPair, removePair, onSubmit }
}

export default { name: 'the-form-profile-filter', components, props, setup }
</script>
