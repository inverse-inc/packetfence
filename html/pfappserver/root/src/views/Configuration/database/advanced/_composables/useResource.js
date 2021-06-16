import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Database Advanced')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getDatabaseAdvanced'),
    getItemOptions: () => $store.dispatch('$_bases/optionsDatabaseAdvanced'),
    updateItem: params => $store.dispatch('$_bases/updateDatabaseAdvanced', params)
  }
}
