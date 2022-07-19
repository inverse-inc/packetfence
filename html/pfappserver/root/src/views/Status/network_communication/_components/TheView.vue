<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline" v-t="'Network Communication'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-row>
        <b-col cols="6">
          <b-tabs small class="filters">
            <b-tab :title="$i18n.t('Search')" class="border-1 border-right border-bottom border-left px-3 pt-3">
              <the-search />
            </b-tab>
          </b-tabs>
        </b-col>
        <b-col cols="6">
            <b-tabs small class="filters" lazy>
              <b-tab class="border-1 border-right border-bottom border-left">
                <template #title>
                  {{ $i18n.t('Devices') }} <b-badge v-if="selectedDevices.length" pill variant="primary" class="ml-1">{{ selectedDevices.length }}</b-badge>
                </template>
                <base-filter-devices />
              </b-tab>
              <b-tab class="border-1 border-right border-bottom border-left">
                <template #title>
                  {{ $i18n.t('Hosts') }} <b-badge v-if="selectedHosts.length" pill variant="primary" class="ml-1">{{ selectedHosts.length }}</b-badge>
                </template>
                <base-filter-hosts />
              </b-tab>
              <b-tab class="border-1 border-right border-bottom border-left">
                <template #title>
                  {{ $i18n.t('Protocols') }} <b-badge v-if="selectedProtocols.length" pill variant="primary" class="ml-1">{{ selectedProtocols.length }}</b-badge>
                </template>
                <base-filter-protocols />
              </b-tab>
            </b-tabs>
        </b-col>
      </b-row>
      <the-data :device="device" />
    </div>
  </b-card>
</template>

<script>
import BaseFilterDevices from './BaseFilterDevices'
import BaseFilterHosts from './BaseFilterHosts'
import BaseFilterProtocols from './BaseFilterProtocols'
import TheSearch from './TheSearch'
import TheData from './TheData'

const components = {
  BaseFilterDevices,
  BaseFilterHosts,
  BaseFilterProtocols,

  TheSearch,
  TheData,
}

const props = {
  device: {
    type: String
  }
}

import { computed, toRefs, watch } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    device
  } = toRefs(props)

  const { root: { $store } = {} } = context

  watch(device, () => {
    if (device.value) {
      $store.dispatch('$_fingerbank_communication/selectDevices', [ device.value ])
    }
  }, { immediate: true })

  const selectedDevices = computed(() => $store.state.$_fingerbank_communication.selectedDevices.value)
  const selectedHosts = computed(() => $store.state.$_fingerbank_communication.selectedHosts.value)
  const selectedProtocols = computed(() => $store.state.$_fingerbank_communication.selectedProtocols.value)

  return {
    selectedDevices,
    selectedHosts,
    selectedProtocols
  }
}

// @vue/component
export default {
  name: 'the-view',
  components,
  props,
  setup
}
</script>

<style lang="scss">
.tabs.filters {
  div[role="tabpanel"] {
    height: 45vh;
    overflow-y: auto;
    overflow-x: hidden;
    .card {
      border: 0px !important;
      box-shadow: $box-shadow;
    }
    .filtered-items > .row {
      border-top: 1px solid rgb(222, 226, 230);
      cursor: pointer;
      &:nth-child(even) {
        background-color: rgba(0, 0, 0, 0.05);
      }
    }
  }
}
</style>
