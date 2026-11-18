import { TheTabs } from '../_components/'

export default [
  {
    path: 'fingerbank/devices',
    name: 'fingerbankDevices',
    component: TheTabs,
    props: () => ({ tab: 'fingerbankDevices', parentId: undefined })
  },
  {
    path: 'fingerbank/devices/:parentId',
    name: 'fingerbankDevicesByParentId',
    component: TheTabs,
    props: (route) => ({ tab: 'fingerbankDevices', parentId: route.params.parentId })
  }
]
