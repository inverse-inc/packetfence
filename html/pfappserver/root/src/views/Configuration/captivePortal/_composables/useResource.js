import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Captive Portal')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getCaptivePortal'),
    getItemOptions: () => $store.dispatch('$_bases/optionsCaptivePortal'),
    updateItem: params => $store.dispatch('$_bases/updateCaptivePortal', params)
  }
}
