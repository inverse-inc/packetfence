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
        return i18n.t('EAP Profile <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone EAP Profile <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New EAP Profile')
    }
  })
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('radiusEap', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'p-0',
      locked: true
    },
    {
      key: 'id',
      label: 'Name', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'default_eap_type',
      label: 'Default EAP', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'tls_tlsprofile',
      label: 'TLS Profile', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'ttls_tlsprofile',
      label: 'TTLS Profile', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'peap_tlsprofile',
      label: 'PEAP Profile', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'fast_config',
      label: 'Fast Profile', // i18n defer
      searchable: true,
      sortable: true,
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
    }
  ],
  fields: [
    {
      value: 'id',
      text: i18n.t('Name'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id'
})
