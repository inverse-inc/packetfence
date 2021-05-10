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

export const useItemDefaults = (meta, props) => {
  const {
    ca_id
  } = toRefs(props)
  return {
    ca_id: ca_id.value,
    scep_days_before_renewal: '0'
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
        return i18n.t('Template <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Template <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Template')
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
    createItem: () => $store.dispatch('$_pkis/createProfile', recomposeProfile(form.value)),
    getItem: () => $store.dispatch('$_pkis/getProfile', id.value).then(item => decomposeProfile(item))
  }
}
