import ConnectorsApi from './connectors/_api'
import ConnectorsApi from './dns/_api'
import ConnectorsDomainsApi from './domains/_api'

export default {
  ...ConnectorsApi,
  ...ConnectorsApi,
  ...ConnectorsDomainsApi
}
