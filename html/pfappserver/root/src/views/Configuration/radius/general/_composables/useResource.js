import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('General Configuration')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getRadiusConfiguration'),
    getItemOptions: () => $store.dispatch('$_bases/optionsRadiusConfiguration'),
    updateItem: params => $store.dispatch('$_bases/updateRadiusConfiguration', params)
  }
}
