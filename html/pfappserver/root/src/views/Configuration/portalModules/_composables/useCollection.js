import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  moduleType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    moduleType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: moduleType.value }
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
        return i18n.t('Portal Module <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Portal Module <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Portal Module')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    moduleType
  } = toRefs(props)
  return computed(() => (moduleType.value || form.value.type))
}

export { useRouter } from '../_router'

export { useStore } from '../_store'
