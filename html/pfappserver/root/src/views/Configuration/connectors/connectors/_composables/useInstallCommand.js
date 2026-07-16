/**
 * Build the post-onboarding connector remote-install command.
 *
 * The proxy serves a per-release script at `/<X.Y>/connector-remote-install.sh`
 * so the target box resolves the matching upstream PacketFence repo (apt/yum)
 * and installs the correct package version. `<X.Y>` is derived from this PF
 * server's version (system_summary "version: X.Y.Z"); when it can't be derived
 * we fall back to the bare URL and the proxy substitutes its configured default.
 */
const PROXY_HOST = 'proxy.saas.packetfence.com'

// Reduce "X.Y.Z" (or "X.Y") to the "X.Y" release slug the proxy expects.
export const pfReleaseSlug = (version) => {
  const match = /^(\d+\.\d+)/.exec(String(version || ''))
  return match ? match[1] : ''
}

export const connectorInstallCommand = ({ id, secret, server, version } = {}) => {
  const release = pfReleaseSlug(version)
  const url = release
    ? `https://${PROXY_HOST}/${release}/connector-remote-install.sh`
    : `https://${PROXY_HOST}/connector-remote-install.sh`
  return `curl -sL ${url} | bash -s -- ${id || ''} ${secret || ''} ${server || ''}`
}
