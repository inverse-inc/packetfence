import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  scope: {
    type: String
  }
}

const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Fingerbank Device <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Fingerbank Device <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Fingerbank Device')
    }
  })
}

export const useItemTitleBadge = props => props.scope

const useRouter = (props, context, form) => {
  const {
    id,
    scope
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'fingerbankDevices' }),
    goToItem: () => $router.push({ name: 'fingerbankDevice', params: { id: form.value.id || id.value, scope: scope.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneFingerbankDevice', params: { id: form.value.id || id.value, scope: 'local' } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_fingerbank/isDevicesLoading']),
    createItem: () => $store.dispatch('$_fingerbank/createDevice', form.value),
    deleteItem: () => $store.dispatch('$_fingerbank/deleteDevice', id.value),
    getItem: () => $store.dispatch('$_fingerbank/getDevice', id.value),
    updateItem: () => $store.dispatch('$_fingerbank/updateDevice', form.value),
  }
}

export default {
  useItemProps,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
