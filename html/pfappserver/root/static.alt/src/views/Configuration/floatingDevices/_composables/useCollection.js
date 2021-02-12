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
        return i18n.t('Floating Device: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Floating Device: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Floating Device')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'floating_devices' }),
    goToItem: () => $router.push({ name: 'floating_device', params: { id: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneFloatingDevice', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_floatingdevices/isLoading']),
    getOptions: () => $store.dispatch('$_floatingdevices/options', id.value),
    createItem: () => $store.dispatch('$_floatingdevices/createFloatingDevice', form.value),
    deleteItem: () => $store.dispatch('$_floatingdevices/deleteFloatingDevice', id.value),
    getItem: () => $store.dispatch('$_floatingdevices/getFloatingDevice', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_floatingdevices/updateFloatingDevice', form.value)
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
