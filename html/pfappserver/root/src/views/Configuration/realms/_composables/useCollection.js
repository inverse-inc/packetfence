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
        return i18n.t('Realm <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Realm <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Realm')
    }
  })
}

export const useItemTitleBadge = (props, context) => {
  const {
    tenantId
  } = toRefs(props)
  const { root: { $store } = {} } = context
  const { name: tenantName } = $store.state.session.tenants.find(tenant => +tenant.id === +tenantId.value)
  return tenantName
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('realms', {
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
      label: 'Name', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'regex',
      label: 'Regex Realm', // i18n defer
      searchable: true,
      visible: true
    },
    {
      key: 'eap',
      label: 'EAP Configuration',
      searchable: true,
      visible: true
    },
    {
      key: 'domain',
      label: 'Domain', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'radius_auth',
      label: 'RADIUS Authentication', // i18n defer
      searchable: true,
      visible: true
    },
    {
      key: 'radius_acct',
      label: 'RADIUS Accounting', // i18n defer
      searchable: true,
      visible: true
    },
    {
      key: 'portal_strip_username',
      label: 'Strip Portal', // i18n defer
      sortable: true,
      visible: true
    },
    {
      key: 'admin_strip_username',
      label: 'Strip Admin', // i18n defer
      sortable: true,
      visible: true
    },
    {
      key: 'radius_strip_username',
      label: 'Strip RADIUS', // i18n defer
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
    },
    {
      key: 'not_sortable',
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
  ]
})
