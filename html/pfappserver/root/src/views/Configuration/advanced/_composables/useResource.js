import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

const useTitle = () => i18n.t('Advanced')

const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsAdvanced'),
    getItem: () => $store.dispatch('$_bases/getAdvanced'),
    updateItem: () => $store.dispatch('$_bases/updateAdvanced', form.value)
  }
}

export default {
  useTitle,
  useStore,
}
