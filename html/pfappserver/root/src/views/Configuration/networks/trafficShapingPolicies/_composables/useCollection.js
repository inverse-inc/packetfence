import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    role
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), id: role.value }
}

export const useItemTitle = (props) => {
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

export const useItemTitleBadge = (props) => {
  const {
    role
  } = toRefs(props)
  return role
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
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
