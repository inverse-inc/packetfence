import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  decomposeCa,
  recomposeCa
} from '../config'

export const useItemProps = {
  id: {
    type: String
  }
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
        return i18n.t('Certificate Authority <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Certificate Authority <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Certificate Authority')
    }
  })
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_pkis/isLoading']),
    createItem: () => $store.dispatch('$_pkis/createCa', recomposeCa(form.value)),
    getItem: () => $store.dispatch('$_pkis/getCa', id.value).then(item => decomposeCa(item))
  }
}
