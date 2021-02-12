import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { defaultsFromMeta } from '../../_config/'

export const useItemProps = {
  id: {
    type: String
  },
  switchGroup: {
    type: String
  }
}

const useItemDefaults = (meta, props) => {
  const {
    switchGroup
  } = toRefs(props)
  return { ...defaultsFromMeta(meta), group: switchGroup.value }
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
        return i18n.t('Switch: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Switch: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Switch')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'switches' }),
    goToItem: () => $router.push({ name: 'switch', params: { id: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneSwitch', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isNew,
    switchGroup
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_switches/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_switches/optionsBySwitchGroup', switchGroup.value)
      else
        return $store.dispatch('$_switches/optionsById', id.value)
    },
    createItem: () => $store.dispatch('$_switches/createSwitch', form.value),
    deleteItem: () => $store.dispatch('$_switches/deleteSwitch', id.value),
    getItem: () => $store.dispatch('$_switches/getSwitch', id.value),
    updateItem: () => $store.dispatch('$_switches/updateSwitch', form.value),
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
