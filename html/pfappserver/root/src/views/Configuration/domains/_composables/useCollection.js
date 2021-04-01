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
        return i18n.t('Domain <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Domain <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Domain')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: (autoJoinDomain) => {
      if (autoJoinDomain)
        $router.push({ name: 'domains', params: { autoJoinDomain: form.value } })
      else
        $router.push({ name: 'domains' })
    },
    goToItem: (item = form.value || {}) => $router
      .push({ name: 'domain', params: { id: item.id } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneDomain', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_domains/isLoading']),
    getOptions: () => $store.dispatch('$_domains/options'),
    createItem: () => $store.dispatch('$_domains/createDomain', form.value),
    deleteItem: () => $store.dispatch('$_domains/deleteDomain', id.value),
    getItem: () => $store.dispatch('$_domains/getDomain', id.value),
    updateItem: () => $store.dispatch('$_domains/updateDomain', form.value),
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
