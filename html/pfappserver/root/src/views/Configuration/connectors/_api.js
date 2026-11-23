import ConnectorsDnsApi from './dns/_api'
import ConnectorsDomainsApi from './domains/_api'

export default {
  ...ConnectorsDnsApi,
  ...ConnectorsDomainsApi
}
