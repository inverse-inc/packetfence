
import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  switchGroup: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    switchGroup
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), group: switchGroup.value }
}

export const useItemTitle = (props) => {
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

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
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
