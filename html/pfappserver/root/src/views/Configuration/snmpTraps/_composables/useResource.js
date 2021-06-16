import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('SNMP')

export const useTitleHelp = () => 'PacketFence_Installation_Guide.html#_snmp_traps_limit'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getSNMPTraps'),
    getItemOptions: () => $store.dispatch('$_bases/optionsSNMPTraps'),
    updateItem: params => $store.dispatch('$_bases/updateSNMPTraps', params)
  }
}
