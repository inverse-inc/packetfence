import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Inline')

export const useTitleHelp = () => 'PacketFence_Installation_Guide.html#_technical_introduction_to_inline_enforcement'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getInline'),
    getItemOptions: () => $store.dispatch('$_bases/optionsInline'),
    updateItem: params => $store.dispatch('$_bases/updateInline', params)
  }
}
