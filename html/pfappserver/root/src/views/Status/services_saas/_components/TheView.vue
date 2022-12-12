<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'Services'"></h4>
    </b-card-header>
    <div class="card-body">

      <b-table ref="tableRef"
        :busy="isLoading"
        :hover="servicesDecorated.length > 0"
        :items="servicesDecorated"
        :fields="serviceFields"
        :sort-by="'service'"
        :sort-desc="false"
        class="mb-0"
        show-empty
        sort-icon-left
        striped
        selectable
        @row-selected="onRowSelected"
      >
        <template v-slot:empty>
          <base-table-empty :is-loading="isLoading">{{ $i18n.t('No Services found') }}</base-table-empty>
        </template>
        <template #head(selected)>
          <span @click.stop.prevent="onAllSelected">
            <template v-if="selected.length > 0">
              <icon name="check-square" class="bg-white text-success" scale="1.125" />
            </template>
            <template v-else>
              <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
            </template>
          </span>
        </template>
        <template #top-row v-if="selected.length">
          <td :colspan="serviceFields.length">
            <base-button-bulk-actions
              :selectedItems="selectedItems" :visibleColumns="serviceFields" />
          </td>
        </template>
        <template #cell(selected)="{ index, rowSelected }">
          <span @click.stop="onItemSelected(index)">
            <template v-if="rowSelected">
              <icon name="check-square" class="bg-white text-success" scale="1.125" />
            </template>
            <template v-else>
              <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
            </template>
          </span>
        </template>
        <template v-slot:cell(available)="{ value }">
          <icon name="circle" :class="(value) ? 'text-success' : 'text-danger'" class="fa-overlap mr-1" />
        </template>
        <template v-slot:cell(status)="{ item }">
          <div>
            <b-progress :max="item.total_replicas" height="2em" :animated="item.updated_replicas !== item.total_replicas">
              <b-progress-bar :value="item.updated_replicas" :precision="2" variant="success" :show-value="false"></b-progress-bar>
              <b-progress-bar :value="item.total_replicas - item.updated_replicas" :precision="2" variant="warning" :show-value="false" striped></b-progress-bar>
            </b-progress>
            <small>{{ item.updated_replicas }}/{{ item.total_replicas }} {{ $i18n.t('Replicas') }}</small>
          </div>
        </template>
        <template v-slot:cell(actions)="{ item }">
          <b-button
            class="m-1" variant="outline-primary" @click="doRestart(item)" :disabled="isLoading"><icon name="redo" class="mr-1" /> {{ $i18n.t('Restart') }}</b-button>
        </template>
      </b-table>
      <b-container fluid v-if="selected.length"
        class="p-0">
        <base-button-bulk-actions
          :selectedItems="selectedItems" :visibleColumns="serviceFields" class="m-3" />
      </b-container>
    </div>
  </b-card>
</template>

<script>
import {
  BaseTableEmpty
} from '@/components/new/'
import BaseButtonBulkActions from './BaseButtonBulkActions'

const components = {
  BaseButtonBulkActions,
  BaseTableEmpty
}

import { computed, onMounted, ref } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import i18n from '@/utils/locale'
//import { localeStrings } from '../../services/config'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  onMounted(() => $store.dispatch('k8s/getServices'))
  const isLoading = computed(() => $store.getters['k8s/isLoading'])
  const services = computed(() => $store.state.k8s.services)
  const serviceFields = computed(() => {
    return [
      {
        key: 'selected',
        thStyle: 'width: 40px;', tdClass: 'text-center',
        locked: true,
        stickyColumn: true,

      },
      {
        key: 'available',
        thStyle: 'width: 40px;', tdClass: 'text-center',
        locked: true,
        stickyColumn: true,
      },
      {
        key: 'service',
        tdClass: 'text-nowrap',
        label: i18n.t('Service'),
        sortable: true,
        visible: true,
        stickyColumn: true,
      },
      {
        key: 'status',
        tdClass: 'text-nowrap',
        label: i18n.t('Status'),
        sortable: true,
        visible: true,
        stickyColumn: true,
      },
      {
        key: 'actions',
        label: null,
        class: 'col-no-overflow text-right p-0',
        locked: true
      }
    ]
  })

  const servicesDecorated = computed(() => Object.entries(services.value).reduce((arr, [service, data]) => {
    return [...arr, { service, ...data }]
  }, []))

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, servicesDecorated, 'service')

  const doRestart = ({ service }) => $store.dispatch('k8s/restartService', service)

  return {
    serviceFields,
    servicesDecorated,
    isLoading,

    tableRef,
    ...selected,
    doRestart,
  }
}

// @vue/component
export default {
  name: 'the-view',
  components,
  setup
}
</script>
