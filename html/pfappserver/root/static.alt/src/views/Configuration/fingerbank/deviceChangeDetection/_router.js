import { TheTabs } from '../_components/'

export default [
  {
    path: 'fingerbank/device_change_detection',
    name: 'fingerbankDeviceChangeDetection',
    component: TheTabs,
    props: (route) => ({ tab: 'device_change_detection', query: route.query.query })
  },
]
