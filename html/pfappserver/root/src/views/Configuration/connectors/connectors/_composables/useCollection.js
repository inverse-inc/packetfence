import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Cloud Connector <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Cloud Connector <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Cloud Connector')
    }
  })
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
      key: 'status',
      label: 'Tunnel', // i18n defer
      thStyle: 'width: 110px;',
      visible: true
    },
    {
      key: 'id',
      label: 'Identifier', // i18n defer
      required: true,
      searchable: true,
      visible: true
    },
    {
      key: 'description',
      label: 'Description', // i18n defer
      searchable: true,
      visible: true
    },
    {
      key: 'static_ports',
      label: 'Static ports', // i18n defer
      visible: true
    },
    {
      key: 'version',
      label: 'Version', // i18n defer
      visible: true
    },
    {
      key: 'issues',
      label: 'Issues', // i18n defer
      visible: true
    },
    {
      key: 'networks',
      label: 'Networks', // i18n defer
      required: true,
      visible: false
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
    }
  ]
})
