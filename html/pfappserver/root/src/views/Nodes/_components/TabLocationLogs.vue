<template>
  <b-tab title="Location">
    <template v-slot:title>
      {{ $t('Location') }} <b-badge pill v-if="node && node.locations && node.locations.length > 0" variant="light" class="ml-1">{{ node.locations.length }}</b-badge>
    </template>
    <b-table v-if="node"
      :items="node.locations" :fields="locationLogFields" :sort-by="locationSortBy" :sort-desc="locationSortDesc" responsive show-empty sort-icon-left striped>
      <template v-slot:cell(switch)="location">
        <b-button variant="link" :to="{ name: 'switch', params: { id: location.item.switch_ip } }">{{ location.item.switch_ip }}</b-button> / <mac>{{ location.item.switch_mac }}</mac><br/>
        <b-badge class="mr-1" v-if="location.item.port">{{ $t('Port') }}: {{ location.item.port }} <span v-if="location.item.ifDesc">({{ location.item.ifDesc }})</span></b-badge>
        <b-badge class="mr-1" v-if="location.item.ssid"><icon name="wifi" class="align-baseline" scale=".6"></icon> {{ location.item.ssid }}</b-badge>
        <b-badge class="mr-1">{{ $t('Role') }}: {{ location.item.role }}</b-badge>
        <b-badge>{{ $t('VLAN') }}: {{ location.item.vlan }}</b-badge>
      </template>
      <template v-slot:cell(connection_type)="location">
        {{ location.item.connection_type }} {{ connectionSubType(location.item.connection_sub_type) }}
      </template>
      <template v-slot:empty>
        <pf-empty-table :is-loading="isLoading" text="">{{ $t('No location logs found') }}</pf-empty-table>
      </template>
    </b-table>
    <div class="mt-3" v-if="canReevaluateAccess || canRestartSwitchport">
      <div class="border-top pt-3">
        <template v-if="canReevaluateAccess">
          <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="isLoading" @click="reevaluateAccess">{{ $i18n.t('Reevaluate Access') }}</b-button>
        </template>
        <template v-else>
          <span v-b-tooltip.hover.top.d300 :title="$i18n.t('Node has no locations.')">
            <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="true">{{ $i18n.t('Reevaluate Access') }}</b-button>
          </span>
        </template>
        <template v-if="canRestartSwitchport">
          <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="isLoading" @click="restartSwitchport">{{ $i18n.t('Restart Switch Port') }}</b-button>
        </template>
        <template v-else>
          <span v-b-tooltip.hover.top.d300 :title="$i18n.t('Node has no open wired connections.')">
            <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="true">{{ $i18n.t('Restart Switch Port') }}</b-button>
          </span>
        </template>    
      </div>
    </div>
  </b-tab>
</template>
<script>
import pfEmptyTable from '@/components/pfEmptyTable'

const components = {
  pfEmptyTable
}

const props = {
  id: {
    type: String
  }
}

import { computed, ref, toRefs } from '@vue/composition-api'
import { pfEapType as eapType } from '@/globals/pfEapType'
import network from '@/utils/network'
import { useStore } from '../_composables/useCollection'
import { locationLogFields } from '../_config/'

const setup = (props, context) => {

  const { id } = toRefs(props)
  const { root: { $store } = {} } = context

  const node = computed(() => $store.state.$_nodes.nodes[id.value])

  const locationSortBy = ref('start_time')
  const locationSortDesc = ref(true)

  const connectionSubType = (type) => {
    if (type && eapType[type]) {
      return eapType[type]
    }
  }

  const {
    isLoading,
    reevaluateAccess,
    restartSwitchport
  } = useStore(props, context)  

  const canReevaluateAccess = computed(() => {
    const { locations = [] } = node.value || {}
    return locations.length > 0
  })
  
  const canRestartSwitchport = computed(() => {
    const { locations = [] } = node.value || {}
    return locations
      .filter(node =>
        node.end_time === '0000-00-00 00:00:00' && // require zero end_time
        network.connectionTypeToAttributes(node.connection_type).isWired // require 'Wired'
      )
      .length > 0
  })
  
  return {
    locationLogFields,
    
    locationSortBy,
    locationSortDesc,
    connectionSubType,
    isLoading,
    node,
    canReevaluateAccess,
    reevaluateAccess,
    canRestartSwitchport,
    restartSwitchport
  }
}
// @vue/component
export default {
  name: 'tab-location-logs',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>