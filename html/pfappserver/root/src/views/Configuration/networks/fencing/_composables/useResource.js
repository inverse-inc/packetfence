import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

const useTitle = () => i18n.t('Fencing')

const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsFencing'),
    getItem: () => $store.dispatch('$_bases/getFencing'),
    updateItem: () => {
      return $store.dispatch('$_bases/updateFencing', form.value)
    }
  }
}

export default {
  useTitle,
  useStore,
}
