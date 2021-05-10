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
        return i18n.t('Switch <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Switch <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Switch')
    }
  })
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
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
