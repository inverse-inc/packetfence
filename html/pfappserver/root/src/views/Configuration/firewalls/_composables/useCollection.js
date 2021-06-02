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

export const useStore = (props, context, form) => {
  const {
    id,
    isClone,
    isNew,
    firewallType
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_firewalls/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_firewalls/optionsByFirewallType', firewallType.value)
      else
        return $store.dispatch('$_firewalls/optionsById', id.value)
    },
    createItem: () => $store.dispatch('$_firewalls/createFirewall', form.value),
    deleteItem: () => $store.dispatch('$_firewalls/deleteFirewall', id.value),
    getItem: () => $store.dispatch('$_firewalls/getFirewall', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_firewalls/updateFirewall', form.value),
  }
}

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('firewalls', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'p-0',
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
  sortBy: 'id',
  defaultCondition: () => ({ op: 'and', values: [
    { op: 'or', values: [
      { field: 'id', op: 'contains', value: null },
      { field: 'port', op: 'contains', value: null },
      { field: 'type', op: 'contains', value: null }
    ] }
  ] })
})