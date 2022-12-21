import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemTitle = (props) => {
  const {
    id
  } = toRefs(props)
  return computed(() => id.value.toUpperCase())
}

export const useServices = (props) => {
  return computed(() => {
    const { id } = props
    const message = i18n.t('Some services must be restarted to load the new certificate.')
    return (() => {
      switch (id) {
        case 'http':
          return {
            message,
            services: ['haproxy-portal', 'haproxy-admin'],
            k8s_services: ['haproxy-portal', 'haproxy-admin']
          }
          //break
        case 'radius':
          return {
            message,
            services: ['radiusd-auth'],
            k8s_services: ['radiusd-auth']
          }
          //break
      }
    })()
  })
}

export { useStore } from '../_store'
