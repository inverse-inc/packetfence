import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Database ProxySQL')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getDatabaseProxySQL'),
    getItemOptions: () => $store.dispatch('$_bases/optionsDatabaseProxySQL'),
    updateItem: params => $store.dispatch('$_bases/updateDatabaseProxySQL', params)
  }
}
