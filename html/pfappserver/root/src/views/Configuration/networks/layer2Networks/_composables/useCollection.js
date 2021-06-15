import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta) => ({ ...useDefaultsFromMeta(meta), actions: [] })

export const useItemTitle = (props) => {
  const {
    id
  } = toRefs(props)
  return computed(() => i18n.t('Layer 2 Network <code>{id}</code>', { id: id.value }))
}

export { useRouter } from '../_router'

export { useStore } from '../_store'
