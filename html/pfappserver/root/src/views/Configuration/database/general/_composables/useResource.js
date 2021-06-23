import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Database General')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getDatabase'),
    getItemOptions: () => $store.dispatch('$_bases/optionsDatabase'),
    updateItem: params => $store.dispatch('$_bases/updateDatabase', params)
  }
}
