import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('General')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getGeneral'),
    getItemOptions: () => $store.dispatch('$_bases/optionsGeneral'),
    updateItem: params => $store.dispatch('$_bases/updateGeneral', params)
  }
}

export const useServices = () => computed(() => {
  return {
    message: i18n.t('Modifying the general configuration requires to restart the haproxy-portal service.'),
    services: ['haproxy-portal'],
    k8s_services: ['haproxy-portal']
  }
})
