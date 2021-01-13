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

const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Certificate Authority: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Certificate Authority: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Certificate Authority')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'pkiCas' }),
    goToItem: () => $router.push({ name: 'pkiCa', params: { id: `${form.value.ID}` || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'clonePkiCa', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
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

export default {
  useItemTitle,
  useRouter,
  useStore,
}
