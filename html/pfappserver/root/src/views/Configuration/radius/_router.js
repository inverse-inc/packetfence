import GeneralRoutes from './general/_router'
import EapRoutes from './eap/_router'
import FastRoutes from './fast/_router'
import OcspRoutes from './ocsp/_router'
import SslRoutes from './ssl/_router'
import TlsRoutes from './tls/_router'

export default [
  ...GeneralRoutes,
  ...EapRoutes,
  ...FastRoutes,
  ...OcspRoutes,
  ...SslRoutes,
  ...TlsRoutes
]
