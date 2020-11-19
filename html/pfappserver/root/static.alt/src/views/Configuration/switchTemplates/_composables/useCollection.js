import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta as useCollectionItemDefaults
} from '../../_config/'

const useCollectionItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Switch Template: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Switch Template: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Switch Template')
    }
  })
}

const useCollectionRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'switchTemplates' }),
    goToItem: () => $router.push({ name: 'switchTemplate', params: { id: form.value.id || id.value } }),
    goToClone: () => $router.push({ name: 'cloneSwitchTemplate', params: { id: id.value } }),
  }
}

const useCollectionStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_switch_templates/isLoading']),
    getOptions: () => $store.dispatch('$_switch_templates/options'),
    createItem: () => $store.dispatch('$_switch_templates/createSwitchTemplate', form.value),
    deleteItem: () => $store.dispatch('$_switch_templates/deleteSwitchTemplate', id.value),
    getItem: () => $store.dispatch('$_switch_templates/getSwitchTemplate', id.value),
    updateItem: () => $store.dispatch('$_switch_templates/updateSwitchTemplate', form.value),
  }
}

export default {
  useCollectionItemDefaults,
  useCollectionItemTitle,
  useCollectionRouter,
  useCollectionStore,
}
