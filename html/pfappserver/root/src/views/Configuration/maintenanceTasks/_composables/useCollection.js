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
