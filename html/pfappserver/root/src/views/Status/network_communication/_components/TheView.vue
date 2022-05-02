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
            <b-tabs small>
              <b-tab>
                <template #title>
                  {{ $i18n.t('Categories') }} <b-badge v-if="selectedCategories.length" pill variant="primary" class="ml-1">{{ selectedCategories.length }}</b-badge>
                </template>
                <base-filter-categories :items="items" v-model="selectedCategories" />
              </b-tab>
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
      <b-row>
        <b-col cols="12">
          <b-tabs class="mt-3">
            <b-tab title="Selected" title-link-class="text-secondary">
              <pre>{{ {selectedCategories, selectedDevices, selectedProtocols, selectedHosts} }}</pre>
            </b-tab>
            <b-tab title="Flows">
              <base-data-flows :data="data" :is-loading="isLoading" />
            </b-tab>
            <b-tab title="Data">
              <base-data-table :data="data" :is-loading="isLoading" />
            </b-tab>
            <b-tab title="Protocols">
              <base-data-protocols :data="data" :is-loading="isLoading" />
            </b-tab>
            <b-tab title="Hosts">
              <base-data-hosts :data="data" :is-loading="isLoading" />
            </b-tab>
          </b-tabs>
        </b-col>
      </b-row>
    </div>
  </b-card>
</template>

<script>
/*
import {
  BaseButtonService
} from '@/components/new/'
*/
import BaseDataFlows from './BaseDataFlows'
import BaseDataTable from './BaseDataTable'
import BaseDataProtocols from './BaseDataProtocols'
import BaseDataHosts from './BaseDataHosts'
import BaseFilterCategories from './BaseFilterCategories'
import BaseFilterDevices from './BaseFilterDevices'
import BaseFilterHosts from './BaseFilterHosts'
import BaseFilterProtocols from './BaseFilterProtocols'
import TheSearch from './TheSearch'

const components = {
  BaseDataFlows,
  BaseDataTable,
  BaseDataProtocols,
  BaseDataHosts,

  BaseFilterCategories,
  BaseFilterDevices,
  BaseFilterHosts,
  BaseFilterProtocols,

  TheSearch,
}

const props = {}

import { createDebouncer } from 'promised-debounce'
import { ref, toRefs, watch } from '@vue/composition-api'
import api from '../_api'
import {
  mac,
  proto,
  port,
  host,
  device_class
} from '../mock'
import { useSearch } from '../_composables/useCollection'

const setup = (props, context) => {

  const search = useSearch()
  const {
    reSearch
  } = search
  const {
    fields,
    items,
    limit,
    visibleColumns,
    sortBy,
    sortDesc,
    lastQuery
  } = toRefs(search)

  const selectedCategories = ref([])
  const selectedDevices = ref([])
  const selectedProtocols = ref([])
  const selectedHosts = ref([])

  const data = ref([])
  const isLoading = ref(false)

  let debouncer
  watch([selectedCategories, selectedDevices, selectedProtocols, selectedHosts, items], () => {
    isLoading.value = true
    if (!debouncer) {
      debouncer = createDebouncer()
    }
    debouncer({
      handler: () => {
        const body = {
          fields,
          query: lastQuery,
          sort: ((sortBy.value)
            ? ((sortDesc.value)
              ? [`${sortBy.value} DESC`]
              : [`${sortBy.value}`]
            )
            : undefined // use natural sort
          ),
          limit,
          foo: 'bar'
        }

console.log('api search', JSON.stringify(body, null, 2))

        let timestamp = 1650564944000
        Promise.resolve(api.search(body)).then(({ items }) => {
          data.value = Array(limit.value).fill(null).map(item => {
            timestamp += Math.floor(Math.random() * 60 * 1E3)
            return {
              timestamp: timestamp,
              mac: mac(selectedDevices.value),
              proto: proto(selectedProtocols.value.map(p => p.split('/')[0])),
              port: port(selectedProtocols.value.map(p => +p.split('/')[1])),
              host: host(selectedHosts.value),
              device_class: device_class(selectedCategories.value)
            }
          })
          isLoading.value = false
        })
      },
      time: 300
    })
  })

  return {
    ...toRefs(search),
    selectedCategories,
    selectedDevices,
    selectedProtocols,
    selectedHosts,

    isLoading,
    data,
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
