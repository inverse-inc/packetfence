<template>
  <b-card no-body>
    <b-card-header class="d-flex align-items-center">
      <h4 class="mb-0">{{ $t('Cloud Connectors') }}</h4>
      <small v-if="lastRefresh" class="ml-auto text-muted">
        {{ $t('Updated') }} <timeago :datetime="lastRefresh" :auto-update="60" :locale="$i18n.locale" />
      </small>
      <b-button size="sm" variant="outline-secondary" class="ml-2" :class="{ 'ml-auto': !lastRefresh }" :disabled="isRemoteLoading" @click="onRefresh"
        v-b-tooltip.hover.left.d300 :title="$t('Refresh status and versions (status refreshes every 10 seconds)')">
        <icon name="sync" :spin="isRemoteLoading" />
      </b-button>
    </b-card-header>
    <div class="card-body">
      <b-row class="mb-3">
        <b-col md="4">
          <b-card class="h-100">
            <small class="text-muted">{{ $t('Cloud connectors') }}</small>
            <h4 class="mb-0">{{ items.length }}</h4>
            <small class="text-muted">{{ $t('configured') }}</small>
          </b-card>
        </b-col>
        <b-col md="4">
          <b-card class="h-100">
            <small class="text-muted">{{ $t('Health') }}</small>
            <h4 class="mb-0">
              <b-badge variant="success" class="mr-1">{{ $t('{count} healthy', { count: summary.healthy }) }}</b-badge>
              <b-badge v-if="summary.degraded" variant="warning" class="mr-1">{{ $t('{count} degraded', { count: summary.degraded }) }}</b-badge>
              <b-badge v-if="summary.down" variant="danger" class="mr-1">{{ $t('{count} unreachable', { count: summary.down }) }}</b-badge>
              <b-badge v-if="summary.unknown" variant="secondary">{{ $t('{count} unknown', { count: summary.unknown }) }}</b-badge>
            </h4>
          </b-card>
        </b-col>
        <b-col md="4">
          <b-card class="h-100">
            <small class="text-muted">{{ $t('Updates available') }}</small>
            <h4 class="mb-0">{{ summary.behind }}</h4>
            <small class="text-muted">
              <template v-if="summary.central">{{ $t('behind PacketFence {version}, out of {count} connector(s) reporting a version', { count: summary.reporting, version: summary.central }) }}</template>
              <template v-else>{{ $t('out of {count} connector(s) reporting a version', { count: summary.reporting }) }}</template>
            </small>
          </b-card>
        </b-col>
      </b-row>
      <base-search :use-search="useSearch">
        <b-button variant="outline-primary" @click="goToNew">{{ $t('New Cloud Connector') }}</b-button>
        <b-button variant="outline-secondary" class="ml-1" @click="goToTopology">
          <icon name="project-diagram" class="mr-1" />{{ $t('Traffic Map') }}
        </b-button>
      </base-search>
      <the-topology class="my-3" :items="itemsWithStatus" :remote-info="remoteInfo" :equipment="equipmentInfo" :dns="dnsConfig"
        :interfaces="packetfenceInterfaces" :saas="isSaas"
        :version="packetfenceVersion" :is-loading="isLoading" />
      <base-table-sortable ref="tableRef"
        :busy="isLoading"
        :hover="itemsWithStatus.length > 0"
        :items="itemsWithStatus"
        :fields="visibleColumns"
        class="mb-0 text-nowrap"
        show-empty
        responsive
        striped
        selectable
        @row-clicked="goToItem"
        @row-selected="onRowSelected"
        @items-sorted="onSorted"
      >
        <template v-slot:empty>
          <slot name="emptySearch" v-bind="{ isLoading }">
            <base-table-empty :is-loading="isLoading">{{ $t('No results found') }}</base-table-empty>
          </slot>
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
        <template v-slot:cell(description)="{ item }">
          <div>{{ item.description || item.id }}</div>
          <div v-if="item.description" class="text-monospace small text-muted">{{ item.id }}</div>
        </template>
        <template v-slot:cell(networks)="item">
          <b-badge v-for="(network, index) in item.item.networks" :key="index" class="mr-1" variant="secondary">{{ network }}</b-badge>
        </template>
        <template v-slot:cell(fingerbank_environment)="{ item }">
          <span class="text-monospace small">{{ (item.fingerbank_environment || []).join(', ') }}</span>
        </template>
        <template v-slot:cell(connected)="{ item }">
          <icon name="circle" :class="`text-${healthVariant(item.health.level)}`"
            v-b-tooltip.hover.top.d300 :title="`${healthLabel(item.health.level)}: ${item.health.reasons.join(' · ') || $t('the tunnel is active and every site service works.')}`" />
        </template>
        <template v-slot:cell(role)="{ item }">
          <template v-if="ha(item.id)">
            <b-badge variant="success" class="mr-1"
              v-b-tooltip.hover.top.d300 :title="$t('Active host {host}: holds the virtual IP {vip} and runs the tunnel.', { host: ha(item.id).hostname || ha(item.id).address, vip: ha(item.id).vip })">{{ $t('master') }}</b-badge>
            <span class="text-monospace small">{{ ha(item.id).vip }}</span>
            <b-badge :variant="ha(item.id).alive === ha(item.id).peers.length ? 'light' : 'warning'" class="ml-1 border"
              v-b-tooltip.hover.top.d300 :title="ha(item.id).peers.map(peer => `${peer.hostname || peer.address} (${peer.address}): ${peer.alive ? $t('standby, reporting') : $t('not reporting')}`).join(' · ')">
              {{ $t('{alive}/{count} standby', { alive: ha(item.id).alive, count: ha(item.id).peers.length }) }}
            </b-badge>
          </template>
          <span v-else-if="system(item.id)" class="text-muted">{{ $t('single host') }}</span>
          <span v-else class="text-muted">-</span>
        </template>
        <template v-slot:cell(status)="data">
          <b-badge :variant="statusVariant(data.item.status)"
            v-b-tooltip.hover.top.d300 :title="statusTooltip(data.item.status)">
            {{ statusLabel(data.item.status) }}
          </b-badge>
        </template>
        <template v-slot:cell(static_ports)="{ item }">
          <template v-if="remote(item.id)">
            <b-badge :variant="staticPorts(item.id).bound < staticPorts(item.id).total ? 'danger' : 'light'" class="border">
              {{ staticPorts(item.id).bound }} / {{ staticPorts(item.id).total }}
            </b-badge>
          </template>
          <span v-else class="text-muted">-</span>
        </template>
        <template v-slot:cell(version)="{ item }">
          <template v-if="system(item.id)">
            {{ system(item.id).version }}
            <router-link v-if="remote(item.id).upgrade_available" class="ml-1"
              :to="{ name: 'connectorsConnector', params: { id: item.id }, query: { tab: 'settings' } }" @click.native.stop
              v-b-tooltip.hover.top.d300 :title="$t('Update available: PacketFence is {central}, this connector runs {version}. Click to open the connector settings and update it.', { central: remote(item.id).central_version, version: system(item.id).version })">
              <icon name="arrow-circle-up" class="text-warning" />
            </router-link>
          </template>
          <span v-else class="text-muted">-</span>
        </template>
        <template v-slot:cell(issues)="{ item }">
          <span v-if="remote(item.id) && (remote(item.id).errors || []).length"
            v-b-tooltip.hover.top.d300 :title="remote(item.id).errors.join(' ')">
            <icon name="exclamation-triangle" class="text-warning mr-1" />{{ remote(item.id).errors.length }}
          </span>
          <span v-else class="text-muted">-</span>
        </template>
        <template v-slot:cell(host_ips)="{ item }">
          <span class="text-monospace">{{ remote(item.id) ? (remote(item.id).remote_ips || []).join(', ') : '-' }}</span>
        </template>
        <template v-slot:cell(hostname)="{ item }">{{ system(item.id) ? system(item.id).hostname : '-' }}</template>
        <template v-slot:cell(uptime)="{ item }">{{ system(item.id) ? formatUptime(system(item.id).uptime_seconds) : '-' }}</template>
        <template v-slot:cell(cpu_usage)="{ item }">{{ system(item.id) ? formatPercent(system(item.id).cpu_usage_percent) : '-' }}</template>
        <template v-slot:cell(cpu_count)="{ item }">{{ system(item.id) ? system(item.id).cpu_count : '-' }}</template>
        <template v-slot:cell(mem_usage)="{ item }">{{ system(item.id) ? formatPercent(system(item.id).mem_usage_percent) : '-' }}</template>
        <template v-slot:cell(mem)="{ item }">{{ system(item.id) ? `${formatBytes(system(item.id).mem_used)} / ${formatBytes(system(item.id).mem_total)}` : '-' }}</template>
        <template v-slot:cell(disk_usage)="{ item }">{{ system(item.id) ? formatPercent(system(item.id).disk_usage_percent) : '-' }}</template>
        <template v-slot:cell(disk)="{ item }">{{ system(item.id) ? `${formatBytes(system(item.id).disk_used)} / ${formatBytes(system(item.id).disk_total)}` : '-' }}</template>
        <template v-slot:cell(load)="{ item }">{{ system(item.id) ? `${formatLoad(system(item.id).load1)} / ${formatLoad(system(item.id).load5)} / ${formatLoad(system(item.id).load15)}` : '-' }}</template>
        <template v-slot:cell(dynamic_count)="{ item }">{{ remote(item.id) ? dynamicCount(item.id) : '-' }}</template>
        <template v-slot:cell(terminal)="{ item }">
          <template v-if="system(item.id)">
            {{ system(item.id).terminal_enabled !== true ? $t('disabled') : (system(item.id).terminal_totp === false ? $t('enabled, no TOTP') : $t('enabled, TOTP')) }}
          </template>
          <span v-else class="text-muted">-</span>
        </template>
        <template v-slot:cell(log_files)="{ item }">{{ system(item.id) ? (system(item.id).log_files || []).join(', ') : '-' }}</template>
        <template v-slot:cell(central_version)="{ item }">{{ remote(item.id) ? (remote(item.id).central_version || '-') : '-' }}</template>
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
        <template #head(buttons)>
          <base-search-input-columns
            :disabled="isLoading"
            :value="columns"
            @input="setColumns"
          />
        </template>
        <template #cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right" @click.stop>
            <base-button-confirm v-if="!item.not_deletable"
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete Connector?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
            <b-button
              size="sm" variant="outline-primary" class="mr-1"
              @click.stop.prevent="goToClone(item)"
            >{{ $t('Clone') }}</b-button>
            <b-dropdown size="sm" variant="link" no-caret right class="mr-1" toggle-class="text-decoration-none">
              <template #button-content><icon name="ellipsis-v" /></template>
              <b-dropdown-item :disabled="isLoading" @click="onCopyInstallCommand(item)">{{ $t('Copy install command') }}</b-dropdown-item>
            </b-dropdown>
          </span>
        </template>
      </base-table-sortable>
      <b-container fluid v-if="selected.length"
        class="mt-3 p-0">
        <b-dropdown variant="outline-primary" toggle-class="text-decoration-none">
          <template #button-content>
            {{ $t('{num} selected', { num: selected.length }) }}
          </template>
          <b-dropdown-item @click="onBulkExport">{{ $t('Export to CSV') }}</b-dropdown-item>
        </b-dropdown>
      </b-container>
    </div>
  </b-card>
</template>
<script>
import {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty,
  BaseTableSortable
} from '@/components/new/'

import TheTopology from './TheTopology'

const components = {
  TheTopology,
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty,
  BaseTableSortable
}

import { ref, toRefs, onMounted, onUnmounted, computed, watch } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import i18n from '@/utils/locale'
import api from '../_api'
import { dnsServersOf, listAll } from '../_composables/useDnsTopology'
import { useSearch, useStore, useRouter } from '../_composables/useCollection'
import { connectorInstallCommand } from '../_composables/useInstallCommand'
import {
  formatBytes,
  formatLoad,
  formatPercent,
  formatUptime
} from '../_composables/useRemoteStatus'
import { connectorHa } from '../_composables/useConnectorRows'
import { connectorHealth, healthLabel, healthVariant } from '../_composables/useConnectorHealth'

const REMOTE_CONCURRENCY = 3 // each remote status call takes 1s or more

const setup = (props, context) => {

  const search = useSearch()
  const {
    reSearch
  } = search
  const {
    items,
    visibleColumns
  } = toRefs(search)

  const { root: { $router, $store } = {} } = context

  const {
    deleteItem,
    sortItems,
    getConnectorsStatus
  } = useStore($store)

  const router = useRouter($router)

  const connectorStatuses = ref({})
  const lastRefresh = ref(null)
  let statusInterval = null

  // remote data (version, host IPs, system) of the connectors that are up,
  // kept apart from the search items: rebuilding the items resets the table
  // selection and drag state
  const remoteInfo = ref({})
  const remotePending = ref(0)
  const isRemoteLoading = computed(() => remotePending.value > 0)

  const fetchRemote = ids => {
    const queue = [...ids]
    if (!queue.length)
      return Promise.resolve()
    remotePending.value++
    const worker = () => {
      const id = queue.shift()
      if (!id)
        return Promise.resolve()
      return api.remoteStatusQuiet(id)
        .then(response => {
          remoteInfo.value = { ...remoteInfo.value, [id]: response }
        })
        .catch(() => {
          remoteInfo.value = Object.fromEntries(Object.entries(remoteInfo.value).filter(([key]) => key !== id))
        })
        .then(worker)
    }
    const workers = Array.from({ length: Math.min(REMOTE_CONCURRENCY, queue.length) }, worker)
    return Promise.all(workers).finally(() => {
      remotePending.value--
    })
  }

  const upIds = statuses => Object.keys(statuses).filter(id => statuses[id] === 'up')

  // equipment behind every connector, for the topology
  const equipmentInfo = ref({})
  const fetchEquipment = ids => {
    const queue = [...ids]
    const worker = () => {
      const id = queue.shift()
      if (!id)
        return Promise.resolve()
      return api.equipment(id)
        .then(response => {
          equipmentInfo.value = { ...equipmentInfo.value, [id]: response }
        })
        .catch(() => {})
        .then(worker)
    }
    return Promise.all(Array.from({ length: Math.min(REMOTE_CONCURRENCY, queue.length) }, worker))
  }

  // DNS servers and domains of the connectors, with the connectors in
  // configuration order (the order deciding which tunnel reaches a server)
  const dnsConfig = ref({ connectors: [], servers: [], domains: [] })
  const fetchDnsConfig = () => listAll(api.list)
    .then(connectors => {
      dnsConfig.value = { connectors, ...dnsServersOf(connectors) }
    })
    .catch(() => {
      // gracefully ignore errors, the diagram shows the DNS servers without their domains
    })

  const fetchStatuses = (fetchNewlyUp = true) => {
    return getConnectorsStatus().then(statuses => {
      const next = Object.fromEntries(
        statuses.map(s => [s.id, s.status])
      )
      lastRefresh.value = new Date()
      if (JSON.stringify(next) === JSON.stringify(connectorStatuses.value))
        return
      const previous = connectorStatuses.value
      connectorStatuses.value = next
      // fetch the remote data of the connectors that just came up
      if (fetchNewlyUp)
        fetchRemote(upIds(next).filter(id => previous[id] !== 'up' && !(id in remoteInfo.value)))
    }).catch(() => {
      // gracefully ignore errors
    })
  }

  const onRefresh = () => {
    fetchStatuses(false).then(() => fetchRemote(upIds(connectorStatuses.value)))
    fetchEquipment(items.value.map(item => item.id))
    fetchDnsConfig()
  }

  // equipment of connectors not fetched yet (first search, new connector)
  watch(items, list => {
    fetchEquipment(list.map(item => item.id).filter(id => !(id in equipmentInfo.value)))
    fetchDnsConfig()
  })

  onMounted(() => {
    onRefresh()
    statusInterval = setInterval(() => fetchStatuses(), 10000)
  })

  onUnmounted(() => {
    if (statusInterval) {
      clearInterval(statusInterval)
      statusInterval = null
    }
  })

  // forget the remote data of connectors that are no longer up
  watch(connectorStatuses, statuses => {
    const kept = Object.fromEntries(Object.entries(remoteInfo.value).filter(([id]) => statuses[id] === 'up'))
    if (Object.keys(kept).length !== Object.keys(remoteInfo.value).length)
      remoteInfo.value = kept
  })

  const itemsWithStatus = computed(() => {
    return items.value.map(item => {
      const status = connectorStatuses.value[item.id] || 'unknown'
      return {
        ...item,
        status,
        health: connectorHealth(status, remoteInfo.value[item.id])
      }
    })
  })

  const packetfenceVersion = computed(() => $store.getters['system/version'])
  // PacketFence interfaces, not shown on cloud (pod interfaces)
  const isSaas = computed(() => !!$store.getters['system/isSaas'])
  const packetfenceInterfaces = ref([])
  onMounted(() => {
    $store.dispatch('config/getInterfaces')
      .then(items => {
        packetfenceInterfaces.value = items || []
      })
      .catch(() => {
        // gracefully ignore errors, the diagram shows no PacketFence interface
      })
  })

  const remote = id => remoteInfo.value[id] || null
  const ha = id => connectorHa(remoteInfo.value[id])
  const system = id => (remoteInfo.value[id] && remoteInfo.value[id].system) || null
  const staticPorts = id => {
    const { static_connections: connections = [] } = remote(id) || {}
    return { bound: (connections || []).filter(c => c.bound).length, total: (connections || []).length }
  }
  const dynamicCount = id => {
    const { static_connections: connections = [], bound_remotes: remotes = [] } = remote(id) || {}
    const staticKeys = new Set((connections || []).map(c => `${c.local_proto}:${c.local_port}`))
    return (remotes || []).filter(r => !staticKeys.has(`${r.local_proto}:${r.local_port}`)).length
  }

  const summary = computed(() => {
    const levels = itemsWithStatus.value.map(item => item.health.level)
    const reporting = Object.values(remoteInfo.value).filter(info => info && info.system)
    const central = (reporting.find(info => info.central_version) || {}).central_version
    return {
      healthy: levels.filter(level => level === 'healthy').length,
      degraded: levels.filter(level => level === 'degraded').length,
      down: levels.filter(level => level === 'down').length,
      unknown: levels.filter(level => level === 'unknown').length,
      reporting: reporting.length,
      behind: reporting.filter(info => info.upgrade_available).length,
      central
    }
  })

  const statusLabel = (status) => {
    switch (status) {
      case 'up': return i18n.t('Connected')
      case 'down': return i18n.t('Unreachable')
      default: return i18n.t('Unknown')
    }
  }

  const statusVariant = (status) => {
    switch (status) {
      case 'up': return 'success'
      case 'down': return 'danger'
      default: return 'secondary'
    }
  }

  const statusTooltip = (status) => {
    switch (status) {
      case 'up': return i18n.t('The tunnel is active and the connector answers.')
      case 'down': return i18n.t('The tunnel is inactive or the connector API does not answer.')
      default: return i18n.t('Not seen by the pfconnector server since it started, or the status is unavailable.')
    }
  }

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, itemsWithStatus)
  const {
    selectedItems
  } = selected

  const onBulkExport = () => {
    const filename = `${$router.currentRoute.path.slice(1).replace('/', '-')}-${(new Date()).toISOString()}.csv`
    const csv = useTableColumnsItems(visibleColumns.value, selectedItems.value)
    useDownload(filename, csv, 'text/csv')
  }

  const onCopyInstallCommand = (item) => {
    api.item(item.id).then(connector => {
      const server = $store.getters['system/hostname'] || window.location.hostname
      const version = $store.getters['system/version']
      const command = connectorInstallCommand({ id: connector.id, secret: connector.secret, server, version })
      try {
        navigator.clipboard.writeText(command).then(() => {
          $store.dispatch('notification/info', { message: i18n.t('Install command copied to clipboard.') })
        }).catch(() => {
          $store.dispatch('notification/danger', { message: i18n.t('Could not copy install command to clipboard.') })
        })
      } catch (e) {
        $store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
      }
    }).catch(() => {
      $store.dispatch('notification/danger', { message: i18n.t('Could not fetch connector details.') })
    })
  }

  const onRemove = id => {
    deleteItem({ id })
      .then(() => reSearch())
  }

  const onSorted = _items => {
    items.value = _items
    sortItems({ items: items.value.map(item => item.id) })
      .then(() => reSearch())
  }

  return {
    useSearch,
    itemsWithStatus,
    remoteInfo,
    equipmentInfo,
    dnsConfig,
    packetfenceInterfaces,
    isSaas,
    ha,
    packetfenceVersion,
    lastRefresh,
    isRemoteLoading,
    onRefresh,
    remote,
    system,
    staticPorts,
    dynamicCount,
    summary,
    statusLabel,
    statusVariant,
    statusTooltip,
    healthLabel,
    healthVariant,
    formatBytes,
    formatLoad,
    formatPercent,
    formatUptime,
    tableRef,
    onCopyInstallCommand,
    onRemove,
    onSorted,
    onBulkExport,
    ...router,
    ...selected,
    ...toRefs(search)
  }
}

// @vue/component
export default {
  name: 'the-search',
  inheritAttrs: false,
  components,
  setup
}
</script>
