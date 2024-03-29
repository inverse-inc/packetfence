import InterfacesApi from './interfaces/_api'
import Layer2NetworksApi from './layer2Networks/_api'
import RoutedNetworksApi from './routedNetworks/_api'

export default {
  ...InterfacesApi,
  ...Layer2NetworksApi,
  ...RoutedNetworksApi,
}
