import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta) => ({ ...useDefaultsFromMeta(meta), actions: [] })

export const useItemTitle = (props) => {
  const {
    id
  } = toRefs(props)
  return computed(() => i18n.t('Layer 2 Network <code>{id}</code>', { id: id.value }))
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_layer2_networks/isLoading']),
    getOptions: () => $store.dispatch('$_layer2_networks/options'),
    getItem: () => $store.dispatch('$_layer2_networks/getLayer2Network', id.value),
    updateItem: () => $store.dispatch('$_layer2_networks/updateLayer2Network', form.value),
  }
}
