import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta) => ({ ...useDefaultsFromMeta(meta), actions: [] })

export const useItemTitle = (props) => {
  const {
    id
  } = toRefs(props)
  return computed(() => i18n.t('Layer 2 Network <code>{id}</code>', { id: id.value }))
}

export const useServices = () => computed(() => {
  return {
    message: i18n.t('Creating or modifying a layer 2 network requires services restart.'),
    services: ['iptables', 'pfdhcp', 'pfdns'],
    system_services: [],
    k8s_services: [],
    systemd: false
  }
})

export { useRouter } from '../_router'

export { useStore } from '../_store'
