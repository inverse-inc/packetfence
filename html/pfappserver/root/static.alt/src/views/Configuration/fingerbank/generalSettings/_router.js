import { TheTabs } from '../_components/'

export default [
  {
    path: 'fingerbank/general_settings',
    name: 'fingerbankGeneralSettings',
    component: TheTabs,
    props: (route) => ({ tab: 'general_settings', query: route.query.query })
  }
]
