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

export const useServices = () => computed(() => {
  return {
    message: i18n.t('Some services must be restarted to load the new settings.'),
    services: ['haproxy-portal', 'httpd.portal'],
    k8s_services: ['haproxy-portal', 'httpd-portal']
  }
})
