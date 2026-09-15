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
        return i18n.t('Connector <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Connector <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Connector')
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
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'id',
      label: 'Identifier', // i18n defer
      required: true,
      searchable: true,
      visible: true
    },
    {
      key: 'status',
      label: 'Status', // i18n defer
      thStyle: 'width: 80px;', tdClass: 'text-center',
      visible: true
    },
    {
      key: 'description',
      label: 'Description', // i18n defer
      searchable: true,
      visible: true
    },
    {
      key: 'networks',
      label: 'Networks', // i18n defer
      visible: true
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
