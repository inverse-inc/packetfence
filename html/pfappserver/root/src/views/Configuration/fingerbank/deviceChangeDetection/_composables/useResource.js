import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Fingerbank device change detection')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getFingerbankDeviceChange'),
    getItemOptions: () => $store.dispatch('$_bases/optionsFingerbankDeviceChange'),
    updateItem: params => $store.dispatch('$_bases/updateFingerbankDeviceChange', params)
  }
}
