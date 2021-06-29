import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  firewallType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    firewallType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: firewallType.value }
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
        return i18n.t('Firewall SSO <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Firewall SSO <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Firewall SSO')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    firewallType
  } = toRefs(props)
  return computed(() => (firewallType.value || form.value.type))
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('firewalls', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'id',
      label: 'Hostname or IP', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'type',
      label: 'Firewall Type', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'port',
      label: 'Port', // i18n defer
      searchable: true,
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
      text: i18n.t('Hostname or IP'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'type',
      text: i18n.t('Firewall Type'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'port',
      text: i18n.t('Port'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id'
})
