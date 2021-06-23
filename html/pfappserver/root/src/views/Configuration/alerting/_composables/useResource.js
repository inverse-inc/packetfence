import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Alerting')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getAlerting'),
    getItemOptions: () => $store.dispatch('$_bases/optionsAlerting'),
    updateItem: params => $store.dispatch('$_bases/updateAlerting', params)
  }
}
