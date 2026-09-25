import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Sponsor Login')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getSelfRegLogin'),
    getItemOptions: () => $store.dispatch('$_bases/optionsSelfRegLogin'),
    updateItem: params => $store.dispatch('$_bases/updateSelfRegLogin', params)
  }
}
