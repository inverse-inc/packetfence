import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  scope: {
    type: String
  }
}

export const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Fingerbank DHCP Vendor <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Fingerbank DHCP Vendor <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Fingerbank DHCP Vendor')
    }
  })
}

export const useItemTitleBadge = props => props.scope

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('fingerbankDhcpVendors', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'p-0',
      locked: true
    },
    {
      key: 'id',
      label: 'Identifier', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'value',
      label: 'DHCP Vendor', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'created_at',
      label: 'Created', // i18n defer
      sortable: true,
      visible: true
    },
    {
      key: 'updated_at',
      label: 'Updated', // i18n defer
      sortable: true,
      visible: true
    },
    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    }
  ],
  fields: [
    {
      value: 'id',
      text: i18n.t('Identifier'),
      types: [conditionType.INTEGER]
    },
    {
      value: 'value',
      text: i18n.t('DHCP Vendor'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id'
})
