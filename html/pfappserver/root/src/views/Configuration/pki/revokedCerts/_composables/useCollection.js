import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  }
}

export const useItemTitle = (props) => {
  const {
    id
  } = toRefs(props)
  return computed(() => i18n.t('Revoked Certificate <code>{id}</code>', { id: id.value }))
}

export { useRouter } from '../_router'

export const useStore = (props, context) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_pkis/isLoading']),
    getItem: () => $store.dispatch('$_pkis/getRevokedCert', id.value)
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
  }
}
