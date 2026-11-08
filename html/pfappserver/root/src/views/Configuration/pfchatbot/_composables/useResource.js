import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('NACBot')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getPfchatbot'),
    getItemOptions: () => $store.dispatch('$_bases/optionsPfchatbot'),
    updateItem: params => $store.dispatch('$_bases/updatePfchatbot', params)
  }
}

export const useServices = () => computed(() => {
  return {
    message: i18n.t('Changes to most NACBot settings require a restart of the assistant service to take effect.'),
    system_services: ['packetfence-chatbot'],
  }
})
