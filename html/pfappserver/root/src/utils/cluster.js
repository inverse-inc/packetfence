import store from '@/store'

/**
 * Preload the cluster member list (drives `cluster/isCluster` and the peer
 * lists used for per-node fan-out). Safe to call from router guards:
 * failures resolve silently — standalone installs simply stay non-cluster.
 */
export const loadClusterConfig = () => {
  if (store.state.cluster && store.dispatch) {
    return store.dispatch('cluster/getConfig').catch(() => {})
  }
  return Promise.resolve()
}
