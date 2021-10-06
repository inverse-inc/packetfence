import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Monit')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getMonit'),
    getItemOptions: () => $store.dispatch('$_bases/optionsMonit'),
    updateItem: params => $store.dispatch('$_bases/updateMonit', params)
  }
}
