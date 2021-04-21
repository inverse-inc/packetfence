import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta
} from '../../../_config/'

const useItemDefaults = (meta, props) => {
  const {
    role
  } = toRefs(props)
  return { ...defaultsFromMeta(meta), id: role.value }
}

const useItemTitle = (props) => {
  const {
    id,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value:
        return i18n.t('Traffic Shaping Policy <code>{id}</code>', { role: id.value })
      default:
        return i18n.t('New Traffic Shaping Policy')
    }
  })
}

const useItemTitleBadge = (props) => {
  const {
    role
  } = toRefs(props)
  return role
}

const useRouter = (props, context, form) => {
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'traffic_shapings' }),
    goToItem: (item = form.value || {}) => $router
      .push({ name: 'traffic_shaping', params: { id: item.id } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
  }
}

const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_traffic_shaping_policies/isLoading']),
    getOptions: () => $store.dispatch('$_traffic_shaping_policies/options'),
    createItem: () => $store.dispatch('$_traffic_shaping_policies/createTrafficShapingPolicy', form.value),
    deleteItem: () => $store.dispatch('$_traffic_shaping_policies/deleteTrafficShapingPolicy', id.value),
    getItem: () => $store.dispatch('$_traffic_shaping_policies/getTrafficShapingPolicy', id.value),
    updateItem: () => $store.dispatch('$_traffic_shaping_policies/updateTrafficShapingPolicy', form.value),
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
