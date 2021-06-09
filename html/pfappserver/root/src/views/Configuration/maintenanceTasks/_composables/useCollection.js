import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemTitle = (props) => {
  const {
    id
  } = toRefs(props)
  return computed(() => i18n.t('Maintenance Task <code>{id}</code>', { id: id.value }))
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_maintenance_tasks/isLoading']),
    getOptions: () => $store.dispatch('$_maintenance_tasks/options', id.value),
    createItem: () => $store.dispatch('$_maintenance_tasks/createMaintenanceTask', form.value),
    getItem: () => $store.dispatch('$_maintenance_tasks/getMaintenanceTask', id.value),
    updateItem: () => $store.dispatch('$_maintenance_tasks/updateMaintenanceTask', form.value),
  }
}

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/views/Configuration/_store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('maintenanceTasks', {
  api,
  sortBy: null, // use natural order (sortable)
  columns: [ // output uses natural order (w/ sortable drag-drop), ensure NO columns are 'sortable: true'
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'p-0',
      locked: true
    },
    {
      key: 'status',
      label: 'Status', // i18n defer
      visible: true
    },
    {
      key: 'id',
      label: 'Name', // i18n defer
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
      key: 'schedule',
      label: 'Schedule', // i18n defer
      searchable: true,
      visible: true
    },
    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    },
  ],
  fields: [
    {
      value: 'id',
      text: i18n.t('Name'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'description',
      text: i18n.t('Description'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'schedule',
      text: i18n.t('Schedule'),
      types: [conditionType.SUBSTRING]
    }
  ],
  defaultCondition: () => ({ op: 'and', values: [
    { op: 'or', values: [
      { field: 'id', op: 'contains', value: null },
      { field: 'description', op: 'contains', value: null },
      { field: 'schedule', op: 'contains', value: null }
    ] }
  ] })
})
