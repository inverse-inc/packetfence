import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Monit')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getMonit'),
    getItemOptions: () => $store.dispatch('$_bases/optionsMonit'),
    updateItem: params => $store.dispatch('$_bases/updateMonit', params)
  }
}

export const useServices = () => computed(() => {
  return {
    message: i18n.t('Creating or modifying the monit configuration requires to restart the monit service.'),
    system_services: ['monit'],
    systemd: true
  }
})
