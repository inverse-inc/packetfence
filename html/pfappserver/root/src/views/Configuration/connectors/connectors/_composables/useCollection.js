import { computed, toRefs } from '@vue/composition-api'
import escape from 'lodash/escape'
import i18n from '@/utils/locale'

// the title is HTML: the description is free text
export const useItemTitle = (props, context, form) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    const { description } = form.value || {}
    switch (true) {
      case !isNew.value && !isClone.value && !!description:
        return i18n.t('Cloud Connector {description} <small class="text-muted text-monospace">{id}</small>', { description: escape(description), id: escape(id.value) })
      case !isNew.value && !isClone.value:
        return i18n.t('Cloud Connector <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Cloud Connector <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Cloud Connector')
    }
  })
}

// Environment handed to the Fingerbank Collector of a new connector: send its
// Fingerbank API queries through the tunnel (the connector's 127.0.0.1:8443
// bind, forwarded by PacketFence to api-ss.fingerbank.org:443) rather than
// through the connector host's own Internet access, and forward the DHCP
// packets it captures on the site to PacketFence (pfdhcplistener replacement:
// fingerprinting and IP tracking of the devices behind the connector). Kept
// here rather than in the form meta: the API reports every list field with an
// empty default.
export const fingerbankEnvironmentDefaults = [
  { name: 'FINGERBANK_API_HOST', value: 'api-ss.fingerbank.org' },
  { name: 'FINGERBANK_API_HOST_OVERRIDE_IP', value: '127.0.0.1' },
  { name: 'FINGERBANK_API_PORT', value: '8443' },
  { name: 'COLLECTOR_DHCP_FORWARD_ENABLED', value: 'true' }
]

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta) => {
  return { ...useDefaultsFromMeta(meta), fingerbank_environment: fingerbankEnvironmentDefaults.map(e => ({ ...e })) }
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('connectorsConnectors', {
  api,
  sortBy: null, // use natural order (sortable)
  // Client-side columns (status and remote data) are filled from
  // config/connectors/status and pfconnector-remotes/{id}/status, not from
  // the search: the search returns them as null.
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'description',
      label: 'Description', // i18n defer
      // the identifier is shown on a second line, see TheSearch
      searchable: true,
      visible: true
    },
    {
      key: 'id',
      label: 'Identifier', // i18n defer
      required: true,
      searchable: true,
      visible: false
    },
    {
      key: 'connected',
      label: 'Connected', // i18n defer
      thClass: 'text-center', tdClass: 'text-center',
      thStyle: 'width: 90px;',
      visible: true
    },
    {
      key: 'status',
      label: 'Tunnel', // i18n defer
      thStyle: 'width: 110px;',
      visible: false
    },
    {
      key: 'role',
      label: 'High availability', // i18n defer
      visible: true
    },
    {
      key: 'static_ports',
      label: 'Static ports', // i18n defer
      visible: false
    },
    {
      key: 'version',
      label: 'Version', // i18n defer
      visible: true
    },
    {
      key: 'issues',
      label: 'Issues', // i18n defer
      visible: false
    },
    {
      key: 'networks',
      label: 'Networks', // i18n defer
      required: true,
      searchable: true,
      visible: true
    },
    {
      key: 'host_ips',
      label: 'Host IP(s)', // i18n defer
      visible: false
    },
    {
      key: 'hostname',
      label: 'Hostname', // i18n defer
      visible: false
    },
    {
      key: 'uptime',
      label: 'Uptime', // i18n defer
      visible: false
    },
    {
      key: 'cpu_usage',
      label: 'CPU %', // i18n defer
      visible: false
    },
    {
      key: 'cpu_count',
      label: 'CPUs', // i18n defer
      visible: false
    },
    {
      key: 'mem_usage',
      label: 'Memory %', // i18n defer
      visible: false
    },
    {
      key: 'mem',
      label: 'Memory used / total', // i18n defer
      visible: false
    },
    {
      key: 'disk_usage',
      label: 'Disk %', // i18n defer
      visible: false
    },
    {
      key: 'disk',
      label: 'Disk used / total', // i18n defer
      visible: false
    },
    {
      key: 'load',
      label: 'Load (1/5/15m)', // i18n defer
      visible: false
    },
    {
      key: 'dynamic_count',
      label: 'On-demand forwards', // i18n defer
      visible: false
    },
    {
      key: 'terminal',
      label: 'Terminal', // i18n defer
      visible: false
    },
    {
      key: 'log_files',
      label: 'Log files', // i18n defer
      visible: false
    },
    {
      key: 'central_version',
      label: 'PacketFence version', // i18n defer
      visible: false
    },
    {
      key: 'fingerbank_environment',
      label: 'Fingerbank Environment', // i18n defer
      visible: false
    },
    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    },
    {
      key: 'not_deletable',
      required: true,
      visible: false
    },
    {
      key: 'not_sortable',
      required: true,
      visible: false
    },
  ],
  fields: [
    {
      value: 'id',
      text: i18n.t('Identifier'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'description',
      text: i18n.t('Description'),
      types: [conditionType.SUBSTRING]
    },
    // lists are matched as stored, comma-joined: use "contains" for one entry
    {
      value: 'networks',
      text: i18n.t('Networks'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'fingerbank_environment',
      text: i18n.t('Fingerbank Environment'),
      types: [conditionType.SUBSTRING]
    }
  ]
})
