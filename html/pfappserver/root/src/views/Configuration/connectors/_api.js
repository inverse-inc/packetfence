import ConnectorsApi from './connectors/_api'
import ConnectorsDnsApi from './dns/_api'
import ConnectorsDomainsApi from './domains/_api'

export default {
  ...ConnectorsApi,
  ...ConnectorsDnsApi,
  ...ConnectorsDomainsApi
}
