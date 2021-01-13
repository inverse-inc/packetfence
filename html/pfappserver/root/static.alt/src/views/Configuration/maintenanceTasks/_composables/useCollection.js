import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta as useItemDefaults
} from '../../_config/'

const useItemTitle = (props) => {
  const {
    id
  } = toRefs(props)
  return computed(() => i18n.t('Maintenance Task: <code>{id}</code>', { id: id.value }))
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'maintenance_tasks' }),
    goToItem: () => $router.push({ name: 'maintenance_task', params: { id: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
  }
}

const useStore = (props, context, form) => {
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

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
