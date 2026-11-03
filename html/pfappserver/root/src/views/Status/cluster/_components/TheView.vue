<template>
  <div>
    <b-card no-body>
      <b-card-header>
        <h4 class="d-inline" v-t="'Cluster Virtual IPs'"></h4>
        <b-button size="sm" variant="outline-primary" class="float-right" :disabled="isLoading" @click="refresh">
          <icon name="sync" :spin="isLoading" class="mr-1" /> {{ $t('Refresh') }}
        </b-button>
        <p class="mb-0 mt-2" v-t="'Realtime ownership of the cluster virtual IPs. Since is the time the current owner became master, as reported by keepalived.'"></p>
      </b-card-header>
      <div class="card-body">
        <b-table
          :fields="vipFields"
          :items="vips"
          :hover="vips.length > 0"
          show-empty
          responsive
          fixed
          striped
        >
          <template v-slot:empty>
            <base-table-empty :is-loading="isLoading" text="">{{ $t('No virtual IPs found') }}</base-table-empty>
          </template>
          <template #cell(vip)="{ item }">
            {{ item.vip }}
            <b-badge v-if="item.management" pill variant="primary" class="ml-1">{{ $t('Management') }}</b-badge>
          </template>
          <template #cell(owners)="{ item }">
            <b-badge v-if="item.status === 'unknown'" pill variant="secondary" v-b-tooltip.hover.top :title="$t('A member of the cluster could not be queried, it may hold this virtual IP.')">{{ $t('Unknown') }}</b-badge>
            <b-badge v-else-if="item.owners.length === 0" pill variant="danger">{{ $t('No owner') }}</b-badge>
            <template v-else>
              <b-badge v-for="owner in item.owners" :key="owner" pill :variant="(item.owners.length > 1) ? 'danger' : 'success'" class="mr-1">{{ owner }}</b-badge>
              <b-badge v-if="item.owners.length > 1" pill variant="warning">{{ $t('Split brain') }}</b-badge>
            </template>
          </template>
          <template #cell(since)="{ item }">
            <template v-if="item.since">
              {{ formatDate(item.since) }}
              <small class="text-muted d-block">{{ $t('for {duration}', { duration: relativeDate(item.since) }) }}</small>
            </template>
            <span v-else class="text-muted">{{ $t('Unknown') }}</span>
          </template>
        </b-table>
      </div>
    </b-card>

    <b-card no-body class="mt-3">
      <b-card-header>
        <h4 class="d-inline" v-t="'Cluster Members'"></h4>
      </b-card-header>
      <div class="card-body">
        <b-table
          :fields="serverFields"
          :items="servers"
          :hover="servers.length > 0"
          show-empty
          responsive
          fixed
          striped
        >
          <template v-slot:empty>
            <base-table-empty :is-loading="isLoading" text="">{{ $t('No cluster members found') }}</base-table-empty>
          </template>
          <template #cell(vips)="{ item }">
            <b-badge v-if="item.error" pill variant="danger">{{ item.error }}</b-badge>
            <template v-else>
              <template v-for="vip in item.vips.filter(vip => vip.owner)">
                <b-badge :key="vip.vip" pill variant="success" class="mr-1">{{ vip.vip }} ({{ vip.interface }})</b-badge>
              </template>
              <span v-if="item.vips.filter(vip => vip.owner).length === 0" class="text-muted">{{ $t('None') }}</span>
            </template>
          </template>
        </b-table>
      </div>
    </b-card>
  </div>
</template>

<script>
import {
  BaseTableEmpty
} from '@/components/new/'

const components = {
  BaseTableEmpty
}

import { computed, onMounted, ref } from '@vue/composition-api'
import { format } from 'date-fns'
import i18n from '@/utils/locale'
import filters from '@/utils/filters'
import api from '../_api'

const setup = () => {

  const isLoading = ref(false)
  const vips = ref([])
  const servers = ref([])

  // the zone is only shown on a multi-zone cluster
  const isMultiZone = computed(() => new Set(servers.value.map(server => server.zone)).size > 1)
  const vipFields = computed(() => ([
    ...((isMultiZone.value) ? [{ key: 'zone', label: i18n.t('Zone') }] : []),
    { key: 'vip', label: i18n.t('Virtual IP') },
    { key: 'interface', label: i18n.t('Interface') },
    { key: 'owners', label: i18n.t('Owner') },
    { key: 'since', label: i18n.t('Since') }
  ]))
  const serverFields = computed(() => ([
    ...((isMultiZone.value) ? [{ key: 'zone', label: i18n.t('Zone') }] : []),
    { key: 'host', label: i18n.t('Server') },
    { key: 'management_ip', label: i18n.t('Management IP') },
    { key: 'vips', label: i18n.t('Virtual IPs held') }
  ]))

  const refresh = () => {
    isLoading.value = true
    api.vips()
      .then(({ items = [], servers: _servers = [] }) => {
        vips.value = items
        servers.value = _servers
      })
      .finally(() => {
        isLoading.value = false
      })
  }
  onMounted(refresh)

  const formatDate = epoch => format(new Date(epoch * 1000), 'YYYY-MM-DD HH:mm:ss')
  const relativeDate = epoch => filters.relativeDate(new Date(epoch * 1000))

  return {
    isLoading,
    vips,
    servers,
    vipFields,
    serverFields,
    refresh,
    formatDate,
    relativeDate
  }
}

// @vue/component
export default {
  name: 'the-view',
  components,
  setup
}
</script>
