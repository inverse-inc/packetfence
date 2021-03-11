import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  prefixRouteName: { // from Configurator
    type: String,
    default: ''
  }
}

const useItemDefaults = (_, props) => {
  const {
    id
  } = toRefs(props)
  return { id: id.value, type: 'none' }
}

const useItemTitle = (props, context, form) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    const { master = false } = form.value || {}
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Interface: <code>{id}</code>', { id: ((master) ? master : id.value) })
      case isClone.value:
        return i18n.t('Clone Interface: <code>{id}</code>', { id: ((master) ? master : id.value) })
      default:
        return i18n.t('New Interface VLAN: <code>{id}</code>', { id: ((master) ? master : id.value) })
    }
  })
}

const useItemTitleBadge = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  return computed(() => {
    const { master = false } = form.value || {}
    if (master) {
      const { 1: vlanFromId = null } = id.value.split('.')
      return `VLAN ${vlanFromId}`
    }
    return // don't show
  })
}

const useRouter = (props, context, form) => {
  const {
    id,
    prefixRouteName
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: `${prefixRouteName.value}interfaces` }),
    goToItem: () => {
      let { id = id.value, vlan } = form.value
      if (id.indexOf('.') === -1 && vlan) // if `id` omits `vlan` and `vlan` is defined
        id += `.${vlan}` // append `vlan` to `id`
      return $router.push({ name: `${prefixRouteName.value}interface`, params: { id } })
        .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
    },
    goToClone: () => $router.push({ name: `${prefixRouteName.value}cloneInterface`, params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_interfaces/isLoading']),
    createItem: () => $store.dispatch('$_interfaces/createInterface', form.value),
    deleteItem: () => $store.dispatch('$_interfaces/deleteInterface', id.value),
    getItem: () => $store.dispatch('$_interfaces/getInterface', id.value).then(item => {
      if (isClone.value) {
        item.id = item.master
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_interfaces/updateInterface', form.value),
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
