import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  scanType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    scanType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: scanType.value }
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
        return i18n.t('Scan Engine <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Scan Engine <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Scan Engine')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    scanType
  } = toRefs(props)
  return computed(() => {
    const { type = scanType.value } = form.value || {}
    return type
  })
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id,
    isClone,
    isNew,
    scanType
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_scans/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_scans/optionsByScanType', scanType.value)
      else
        return $store.dispatch('$_scans/optionsById', id.value)
    },
    createItem: () => $store.dispatch('$_scans/createScanEngine', form.value),
    deleteItem: () => $store.dispatch('$_scans/deleteScanEngine', id.value),
    getItem: () => $store.dispatch('$_scans/getScanEngine', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_scans/updateScanEngine', form.value),
  }
}
