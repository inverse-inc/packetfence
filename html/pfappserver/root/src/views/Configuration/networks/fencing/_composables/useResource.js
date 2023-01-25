import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Fencing')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getFencing'),
    getItemOptions: () => $store.dispatch('$_bases/optionsFencing'),
    updateItem: params => $store.dispatch('$_bases/updateFencing', params)
  }
}

export const useServices = () => computed(() => {
  return {
    message: i18n.t('Creating or modifying the syslog forwarders requires to restart the rsyslog system service.'),
    services: ['pfdns', 'iptables'],
  }
})
