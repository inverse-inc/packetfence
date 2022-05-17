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
        return i18n.t('Role <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Role <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Role')
    }
  })
}

export { useRouter } from '../_router'

import makeSearch from '@/store/factory/search'
import { search as nodesSearch } from '@/views/Nodes/_search'
import api from '../_api'

export const useNodesSearch = makeSearch('networkCommunicationNodes', {
  ...nodesSearch,
  useCursor: false,
  limit: 500,
  sortBy: 'mac',
  sortDesc: false,
})

export const useSearch = makeSearch('networkCommunication', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'text-align: center; width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'mac',
      label: i18n.t('Device'),
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'host',
      label: i18n.t('Host'),
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'proto',
      label: i18n.t('Protocol'),
      searchable: true,
      required: true,
      sortable: true
    },
    {
      key: 'port',
      label: i18n.t('Port'),
      searchable: true,
      required: true,
      sortable: true
    },
    {
      key: 'count',
      label: i18n.t('Count'),
      searchable: true,
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    },
  ],
  sortBy: null // use natural order
})
