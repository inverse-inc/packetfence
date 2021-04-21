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
        return i18n.t('WMI Rule <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone WMI Rule <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New WMI Rule')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'wmiRules' }),
    goToItem: (item = form.value || {}) => $router
      .push({ name: 'wmiRule', params: { id: item.id } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneWmiRule', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_wmi_rules/isLoading']),
    getOptions: () => $store.dispatch('$_wmi_rules/options'),
    createItem: () => $store.dispatch('$_wmi_rules/createWmiRule', form.value),
    deleteItem: () => $store.dispatch('$_wmi_rules/deleteWmiRule', id.value),
    getItem: () => $store.dispatch('$_wmi_rules/getWmiRule', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_wmi_rules/updateWmiRule', form.value),
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
