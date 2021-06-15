import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('WRIX Location <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone WRIX Location <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New WRIX Location')
    }
  })
}

export { useRouter } from '../_router'

export { useStore } from '../_store'
