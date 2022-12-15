import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useServices = () => computed(() => {
  return {
    message: i18n.t('Creating or modifying the RADIUS configuration requires services restart.'),
    services: [
      'httpd.aaa',
      'pfacct',
      'radiusd-acct',
      'radiusd-auth',
      'radiusd-cli',
      'radiusd-eduroam',
      'radiusd-load_balancer',
    ],
    k8s_services: [
      'httpd-aaa',
      'pfacct',
      'radiusd-auth'
    ]
  }
})
