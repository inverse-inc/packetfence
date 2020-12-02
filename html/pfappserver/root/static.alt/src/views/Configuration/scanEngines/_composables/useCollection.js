import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta
} from '../../_config/'

export const useItemProps = {
  id: {
    type: String
  },
  scanType: {
    type: String
  }
}

const useItemDefaults = (meta, props) => {
  const {
    scanType
  } = toRefs(props)
  return { ...defaultsFromMeta(meta), type: scanType.value }
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
        return i18n.t('Scan Engine: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Scan Engine: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Scan Engine')
    }
  })
}

const useItemTitleBadge = (props, context, form) => {
  const {
    scanType
  } = toRefs(props)
  return computed(() => {
    const { type = scanType.value } = form.value || {}
    return type
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'scanEngines' }),
    goToItem: () => $router.push({ name: 'scanEngine', params: { id: form.value.id || id.value } }),
    goToClone: () => $router.push({ name: 'cloneScanEngine', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
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

export default {
  useItemProps,
  useItemDefaults,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
