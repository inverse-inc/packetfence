import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta
} from '../../../_config/'

const useItemDefaults = (meta) => ({ ...defaultsFromMeta(meta), actions: [] })

const useItemTitle = (props) => {
  const {
    id
  } = toRefs(props)
  return computed(() => i18n.t('Layer 2 Network <code>{id}</code>', { id: id.value }))
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'interfaces' }),
    goToItem: () => $router.push({ name: 'interface', params: { id: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
  }
}

const useStore = (props, context, form) => {
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

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
