import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta as useItemDefaults
} from '../../_config/'

const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('WRIX Location <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone WRIX Location <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New WRIX Location')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'wrixLocations' }),
    goToItem: () => $router.push({ name: 'wrixLocation', params: { id: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneWrixLocation', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_wrix_locations/isLoading']),
    createItem: () => $store.dispatch('$_wrix_locations/createWrixLocation', form.value),
    deleteItem: () => $store.dispatch('$_wrix_locations/deleteWrixLocation', id.value),
    getItem: () => $store.dispatch('$_wrix_locations/getWrixLocation', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_wrix_locations/updateWrixLocation', form.value),
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
