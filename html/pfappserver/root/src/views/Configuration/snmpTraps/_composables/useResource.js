import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

const useTitle = () => i18n.t('SNMP')

const useTitleHelp = () => 'PacketFence_Installation_Guide.html#_snmp_traps_limit'

const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsSNMPTraps'),
    getItem: () => $store.dispatch('$_bases/getSNMPTraps'),
    updateItem: () => {
      return $store.dispatch('$_bases/updateSNMPTraps', form.value)
    }
  }
}

export default {
  useTitle,
  useTitleHelp,
  useStore,
}
