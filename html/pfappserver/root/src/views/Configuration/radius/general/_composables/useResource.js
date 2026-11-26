import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('General Configuration')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    // SaaS: record_accounting_in_sql is locked and always enabled, a stored 'disabled'
    //  would be refused by the backend on every save and the toggle cannot change it
    getItem: () => $store.dispatch('$_bases/getRadiusConfiguration')
      .then(item => ($store.getters['system/isSaas'])
        ? { ...item, record_accounting_in_sql: 'enabled' }
        : item
      ),
    getItemOptions: () => $store.dispatch('$_bases/optionsRadiusConfiguration'),
    updateItem: params => $store.dispatch('$_bases/updateRadiusConfiguration', params)
  }
}

export { useServices } from '../../_composables/useResource'
