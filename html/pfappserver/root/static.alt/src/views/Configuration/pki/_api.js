import CasApi from './cas/_api'
import CertsApi from './certs/_api'
import ProfilesApi from './profiles/_api'
import RevokeCertsApi from './revokedCerts/_api'

export default {
  ...CasApi,
  ...CertsApi,
  ...ProfilesApi,
  ...RevokeCertsApi
}
