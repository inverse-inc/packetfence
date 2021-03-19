 
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
        return i18n.t('Switch Group <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Switch Group <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Switch Group')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'switch_groups' }),
    goToItem: () => $router.push({ name: 'switch_group', params: { id: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneSwitchGroup', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    isNew,
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_switch_groups/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_switch_groups/options')
      else
        return $store.dispatch('$_switch_groups/options', id.value)
    },
    createItem: () => $store.dispatch('$_switch_groups/createSwitchGroup', form.value),
    deleteItem: () => $store.dispatch('$_switch_groups/deleteSwitchGroup', id.value),
    getItem: () => $store.dispatch('$_switch_groups/getSwitchGroup', id.value),
    updateItem: () => $store.dispatch('$_switch_groups/updateSwitchGroup', form.value),
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
