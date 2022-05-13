<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline" v-t="'Network Communication'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-row>
        <b-col cols="6">
          <b-tabs small>
            <b-tab :title="$i18n.t('Search')" class="border-1 border-right border-bottom border-left px-3 pt-3">
              <the-search />
            </b-tab>
          </b-tabs>
        </b-col>
        <b-col cols="6">
            <b-tabs small lazy>
              <b-tab>
                <template #title>
                  {{ $i18n.t('Devices') }} <b-badge v-if="selectedDevices.length" pill variant="primary" class="ml-1">{{ selectedDevices.length }}</b-badge>
                </template>
                <base-filter-devices :items="items" v-model="selectedDevices" />
              </b-tab>
              <b-tab>
                <template #title>
                  {{ $i18n.t('Protocols') }} <b-badge v-if="selectedProtocols.length" pill variant="primary" class="ml-1">{{ selectedProtocols.length }}</b-badge>
                </template>
                <base-filter-protocols :items="items" v-model="selectedProtocols" />
              </b-tab>
              <b-tab>
                <template #title>
                  {{ $i18n.t('Hosts') }} <b-badge v-if="selectedHosts.length" pill variant="primary" class="ml-1">{{ selectedHosts.length }}</b-badge>
                </template>
                <base-filter-hosts :items="items" v-model="selectedHosts" />
              </b-tab>
            </b-tabs>
        </b-col>
      </b-row>
      <the-data v-bind="{ selectedCategories, selectedDevices, selectedProtocols, selectedHosts }" />
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

import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { useNodesSearch } from '../_composables/useCollection'

const setup = (props, context) => {

 const { root: { $store } = {} } = context

  const search = useNodesSearch()
  const {
    items
  } = toRefs(search)

  const isLoading = computed(() => $store.getters['$_fingerbank_communication/isLoading'])
  const devices = computed(() => $store.getters['$_fingerbank_communication/devices'])
  const protocols = computed(() => $store.getters['$_fingerbank_communication/protocols'])
  const hosts = computed(() => $store.getters['$_fingerbank_communication/hosts'])

  watch(items, () => {
    const nodes = items.value.map(item => item.mac.replace(/[^0-9A-F]/gi, ''))
    $store.dispatch('$_fingerbank_communication/get', { nodes })
  }, { deep: true })

  const selectedCategories = ref([])
  const selectedDevices = ref([])
  const selectedProtocols = ref([])
  const selectedHosts = ref([])

  return {
    ...toRefs(search),

    selectedCategories,
    selectedDevices,
    selectedProtocols,
    selectedHosts,

    isLoading,
    devices,
    protocols,
    hosts,
  }
}

// @vue/component
export default {
  name: 'the-view',
  components,
  setup
}
</script>
