import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Database General')

export const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsDatabase'),
    getItem: () => $store.dispatch('$_bases/getDatabase'),
    updateItem: () => {
      return $store.dispatch('$_bases/updateDatabase', form.value)
    }
  }
}
