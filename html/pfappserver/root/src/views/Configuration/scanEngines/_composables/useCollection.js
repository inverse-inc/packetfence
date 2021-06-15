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

export { useStore } from '../_store'
