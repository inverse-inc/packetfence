import RemoteRoutes from './remote/_router'
import StandardRoutes from './standard/_router'

const routes = [
  ...RemoteRoutes,
  ...StandardRoutes
]

export default routes
