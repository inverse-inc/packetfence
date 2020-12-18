import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  decomposeProfile,
  recomposeProfile
} from '../config'

export const useItemProps = {
  id: {
    type: String
  },
  ca_id: {
    type: String
  }
}

const useItemDefaults = (meta, props) => {
  const {
    ca_id
  } = toRefs(props)
  return { ca_id: ca_id.value }
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
        return i18n.t('Teamplate: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Template: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Template')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'pkiProfiles' }),
    goToItem: () => $router.push({ name: 'pkiProfile', params: { id: form.value.ID || id.value } }),
    goToClone: () => $router.push({ name: 'clonePkiProfile', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    ca_id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_pkis/isLoading']),
    createItem: () => $store.dispatch('$_pkis/createProfile', { ...recomposeProfile(form.value), ca_id: ca_id.value }),
    getItem: () => $store.dispatch('$_pkis/getProfile', id.value).then(item => decomposeProfile(item))
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
