<template>
  <div class="card mx-3 mb-3 bg-light">
    <div class="card-body">
      <b-row align-v="center" class="mb-2">
        <b-col>
          <h6 class="mb-0">
            {{ $i18n.t('Remote Connector Status') }}
            <b-badge v-if="status" :variant="status.connected ? 'success' : 'danger'" class="ml-2">
              {{ status.connected ? $i18n.t('Connected') : $i18n.t('Disconnected') }}
            </b-badge>
            <b-badge v-if="ha" :variant="haPeersAlive.length ? 'info' : 'warning'" class="ml-1"
              :title="haPeersAlive.length ? $i18n.t('High availability: {n} backup host(s) alive', { n: haPeersAlive.length }) : $i18n.t('High availability: no backup host reporting')">
              {{ $i18n.t('HA') }} · {{ ha.vip }}
            </b-badge>
          </h6>
          <small v-if="lastRefresh" class="text-muted">{{ $i18n.t('Last refreshed') }}: {{ lastRefresh }}</small>
        </b-col>
        <b-col cols="auto">
          <b-button size="sm" variant="outline-secondary" class="mr-1" :disabled="isLoading" @click="refresh">
            <icon name="sync" :spin="isLoading" class="mr-1" />{{ $i18n.t('Refresh') }}
          </b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1"
            :disabled="!status || !status.connected || isTerminalLoading || (status.system && status.system.terminal_enabled === false)"
            :title="(status && status.system && status.system.terminal_enabled === false) ? $i18n.t('The terminal is disabled on this connector (PFCONNECTOR_TERMINAL).') : ''"
            @click="openTerminal">
            <icon name="terminal" class="mr-1" />{{ $i18n.t('Open Terminal') }}
          </b-button>
          <b-button v-if="logFiles.length" size="sm" :variant="showLogs ? 'primary' : 'outline-primary'" class="mr-1"
            :disabled="!status || !status.connected"
            @click="showLogs = !showLogs">
            <icon name="scroll" class="mr-1" />{{ $i18n.t('View Logs') }}
          </b-button>
          <b-button v-if="status && status.upgrade_available" size="sm" variant="outline-warning" class="mr-1"
            :disabled="!status.connected || isUpgrading" @click="showUpgradeModal = true">
            <icon name="arrow-circle-up" class="mr-1" />{{ $i18n.t('Upgrade to {version}', { version: status.central_version }) }}
          </b-button>
          <b-button size="sm" variant="outline-danger"
            :disabled="!status || !status.connected || isRestarting" @click="showRestartModal = true">
            <icon name="redo" class="mr-1" />{{ $i18n.t('Restart') }}
          </b-button>
        </b-col>
      </b-row>

      <b-alert :show="errors.length > 0" variant="warning" class="mb-2">
        <div v-for="(error, index) in errors" :key="index">{{ error }}</div>
      </b-alert>

      <template v-if="status">
        <b-row>
          <b-col md="6">
            <h6 class="text-secondary">{{ $i18n.t('Addresses') }}</h6>
            <p class="mb-2">
              <template v-if="status.remote_ips && status.remote_ips.length">
                <b-badge v-for="ip in status.remote_ips" :key="ip" variant="light" class="border mr-1 text-monospace">{{ ip }}</b-badge>
              </template>
              <span v-else class="text-muted">{{ $i18n.t('No IP address reported yet.') }}</span>
            </p>

            <h6 class="text-secondary">{{ $i18n.t('System') }}</h6>
            <b-table-simple v-if="status.system" small borderless class="mb-0">
              <b-tbody>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('Hostname') }}</b-td>
                  <b-td>{{ status.system.hostname }}</b-td>
                </b-tr>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('Version') }}</b-td>
                  <b-td>{{ status.system.version }}</b-td>
                </b-tr>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('Uptime') }}</b-td>
                  <b-td>{{ formatUptime(status.system.uptime_seconds) }}</b-td>
                </b-tr>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('Load (1/5/15m)') }}</b-td>
                  <b-td>{{ formatLoad(status.system.load1) }} / {{ formatLoad(status.system.load5) }} / {{ formatLoad(status.system.load15) }}</b-td>
                </b-tr>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('CPU') }}</b-td>
                  <b-td>{{ status.system.cpu_count }} {{ $i18n.t('cores') }}, {{ formatPercent(status.system.cpu_usage_percent) }}</b-td>
                </b-tr>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('Memory') }}</b-td>
                  <b-td>{{ formatBytes(status.system.mem_used) }} / {{ formatBytes(status.system.mem_total) }} ({{ formatPercent(status.system.mem_usage_percent) }})</b-td>
                </b-tr>
                <b-tr>
                  <b-td class="text-muted">{{ $i18n.t('Disk') }} /</b-td>
                  <b-td>{{ formatBytes(status.system.disk_used) }} / {{ formatBytes(status.system.disk_total) }} ({{ formatPercent(status.system.disk_usage_percent) }})</b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
            <p v-else class="text-muted mb-0">{{ $i18n.t('System information unavailable.') }}</p>

            <template v-if="cacheStats">
              <h6 class="text-secondary mt-3">{{ $i18n.t('Connector Cache') }}</h6>
              <p class="mb-1 small text-muted">
                {{ $i18n.t('The local cache service: cached RADIUS authorizations and credentials replayed when PacketFence is unreachable, and the RADIUS rate limiter.') }}
              </p>
              <b-table-simple small borderless class="mb-0">
                <b-tbody>
                  <b-tr>
                    <b-td class="text-muted">{{ $i18n.t('Cached RADIUS authorizations') }}</b-td>
                    <b-td>{{ cacheStats.devices_in_db }}</b-td>
                  </b-tr>
                  <b-tr>
                    <b-td class="text-muted">{{ $i18n.t('Cached credentials') }}</b-td>
                    <b-td>{{ cacheStats.credential_in_db }}</b-td>
                  </b-tr>
                  <b-tr>
                    <b-td class="text-muted">{{ $i18n.t('Rate limiter keys') }}</b-td>
                    <b-td>{{ cacheStats.keys_in_ratelimit }}</b-td>
                  </b-tr>
                  <b-tr>
                    <b-td class="text-muted">{{ $i18n.t('Database size') }}</b-td>
                    <b-td>{{ formatBytes(cacheStats.db_size) }}</b-td>
                  </b-tr>
                  <b-tr>
                    <b-td class="text-muted">{{ $i18n.t('Memory') }}</b-td>
                    <b-td>{{ formatBytes(cacheStats.mem_alloc) }} <small class="text-muted">{{ $i18n.t('allocated') }}</small> / {{ formatBytes(cacheStats.mem_sys) }} <small class="text-muted">{{ $i18n.t('from the OS') }}</small></b-td>
                  </b-tr>
                </b-tbody>
              </b-table-simple>
            </template>

            <template v-if="hostPackages">
              <h6 class="text-secondary mt-3">{{ $i18n.t('NTLM Authentication Services') }}</h6>
              <p class="mb-1 small text-muted">
                {{ $i18n.t('Needed on this host when an Active Directory domain is behind the connector: the join service creates the machine account and the API service answers NTLM authentications locally.') }}
              </p>
              <b-table-simple small class="mb-1">
                <b-tbody>
                  <b-tr v-for="pkg in hostPackages.packages" :key="pkg.name">
                    <b-td class="text-monospace">{{ pkg.name }}</b-td>
                    <b-td>
                      <b-badge v-if="!hostPackages.available" variant="secondary">{{ $i18n.t('unknown') }}</b-badge>
                      <b-badge v-else-if="pkg.installed" variant="success">{{ $i18n.t('installed') }} <small>{{ pkg.version }}</small></b-badge>
                      <b-badge v-else variant="light" class="border">{{ $i18n.t('not installed') }}</b-badge>
                    </b-td>
                  </b-tr>
                  <b-tr>
                    <b-td class="text-muted">{{ $i18n.t('Join service') }}</b-td>
                    <b-td>
                      <b-badge :variant="hostPackages.ntlm_join_remote_listening ? 'success' : 'light'" :class="{ border: !hostPackages.ntlm_join_remote_listening }">
                        {{ hostPackages.ntlm_join_remote_listening ? $i18n.t('running') : $i18n.t('not running') }}
                      </b-badge>
                    </b-td>
                  </b-tr>
                </b-tbody>
              </b-table-simple>
              <p v-if="hostPackages.install_state" class="mb-1 small" :class="installStateClass">
                {{ $i18n.t('Last install request') }}: {{ hostPackages.install_state }}
              </p>
              <b-button v-if="!ntlmInstalled" size="sm" variant="outline-primary"
                :disabled="!status.connected || isInstalling || installInProgress"
                :title="!hostPackages.available ? $i18n.t('The host package state is unknown (older connector package); the install can still be requested.') : ''"
                @click="showInstallModal = true">
                <icon name="download" class="mr-1" />{{ $i18n.t('Install NTLM Services') }}
              </b-button>
            </template>

            <template v-if="ha">
              <h6 class="text-secondary mt-3">{{ $i18n.t('High Availability') }}</h6>
              <p class="mb-1 small text-muted">
                {{ $i18n.t('Virtual IP {vip}: the host holding it runs the tunnel; the others report to it over the site network and mirror its credential cache. Configure switches, portal redirection and DHCP relays with the virtual IP.', { vip: ha.vip }) }}
              </p>
              <b-table-simple small class="mb-0">
                <b-thead>
                  <b-tr>
                    <b-th>{{ $i18n.t('Host') }}</b-th>
                    <b-th>{{ $i18n.t('Role') }}</b-th>
                    <b-th>{{ $i18n.t('Version') }}</b-th>
                    <b-th>{{ $i18n.t('Since / Last seen') }}</b-th>
                    <b-th>{{ $i18n.t('Cache') }}</b-th>
                    <b-th>{{ $i18n.t('Status') }}</b-th>
                  </b-tr>
                </b-thead>
                <b-tbody>
                  <b-tr>
                    <b-td class="text-monospace">{{ ha.hostname || status.system.hostname }} <small v-if="ha.address" class="text-muted">{{ ha.address }}</small></b-td>
                    <b-td>{{ $i18n.t('master') }}</b-td>
                    <b-td>{{ status.system.version }}</b-td>
                    <b-td>{{ formatDate(ha.since) }}</b-td>
                    <b-td><span class="text-muted">{{ $i18n.t('source') }}</span></b-td>
                    <b-td><b-badge variant="success">{{ $i18n.t('holds the VIP') }}</b-badge></b-td>
                  </b-tr>
                  <b-tr v-for="peer in ha.peers" :key="peer.hostname">
                    <b-td class="text-monospace">{{ peer.hostname }} <small class="text-muted">{{ peer.address }}</small></b-td>
                    <b-td>{{ $i18n.t(peer.state || 'backup') }}<template v-if="peer.priority"> <small class="text-muted">({{ $i18n.t('priority') }} {{ peer.priority }})</small></template></b-td>
                    <b-td>{{ peer.version }}</b-td>
                    <b-td>{{ formatDate(peer.last_seen) }}</b-td>
                    <b-td>
                      <template v-if="peer.cache_synced_at">
                        <b-badge :variant="peer.cache_sync_error ? 'warning' : 'light'" class="border" :title="peer.cache_sync_error || ''">
                          {{ $i18n.t('{n} entries', { n: peer.cache_rows || 0 }) }} · {{ formatDate(peer.cache_synced_at) }}
                        </b-badge>
                      </template>
                      <b-badge v-else variant="warning" :title="peer.cache_sync_error || ''">{{ $i18n.t('not synced') }}</b-badge>
                      <b-badge v-if="peer.totp_seed_synced" variant="light" class="border ml-1"
                        :title="$i18n.t('This host adopted the terminal TOTP seed of the active host: the same authenticator enrollment opens the terminal on it.')">{{ $i18n.t('TOTP seed') }}</b-badge>
                      <b-badge v-else variant="warning" class="ml-1"
                        :title="$i18n.t('This host has not adopted the terminal TOTP seed of the active host yet (it syncs every minute over the local network).')">{{ $i18n.t('TOTP seed') }}</b-badge>
                    </b-td>
                    <b-td>
                      <b-badge :variant="peer.alive ? 'success' : 'danger'">{{ peer.alive ? $i18n.t('alive') : $i18n.t('not reporting') }}</b-badge>
                      <b-button v-if="peer.alive" size="sm" variant="outline-primary" class="ml-2 py-0"
                        :disabled="!status.connected || isSwitching"
                        :title="$i18n.t('Move the virtual IP and the tunnel to this host. Host-level actions (install, terminal, logs, upgrade) then apply to it.')"
                        @click="switchTarget = peer; showSwitchModal = true">
                        <icon name="exchange-alt" class="mr-1" />{{ $i18n.t('Make active') }}
                      </b-button>
                    </b-td>
                  </b-tr>
                </b-tbody>
              </b-table-simple>
              <b-alert :show="!haPeersAlive.length" variant="warning" class="mt-2 mb-0 py-1 small">
                {{ $i18n.t('No backup host is reporting to the master: a failure of this host would interrupt the service.') }}
              </b-alert>
            </template>
          </b-col>
          <b-col md="6">
            <h6 class="text-secondary">{{ $i18n.t('Ports Open on the Connector') }}</h6>
            <p class="mb-1 small text-muted">{{ $i18n.t('Listeners the connector opened on its host for the tunnel, and the PacketFence destination each one forwards to.') }}</p>
            <b-table-simple v-if="localBinds.length" small class="mb-0">
              <b-thead>
                <b-tr>
                  <b-th>{{ $i18n.t('Connector Port') }}</b-th>
                  <b-th>{{ $i18n.t('Protocol') }}</b-th>
                  <b-th>{{ $i18n.t('Destination') }}</b-th>
                </b-tr>
              </b-thead>
              <b-tbody>
                <b-tr v-for="(bind, index) in localBinds" :key="index">
                  <b-td class="text-monospace">{{ bind.local_host || '0.0.0.0' }}:{{ bind.local_port }}</b-td>
                  <b-td>{{ bind.local_proto || 'tcp' }}<small v-if="bind.handler" class="text-muted ml-1">({{ bind.handler }})</small></b-td>
                  <b-td class="text-monospace">{{ bind.remote_host }}:{{ bind.remote_port }}</b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
            <p v-else class="text-muted mb-0">{{ $i18n.t('No listener reported by the connector.') }}</p>

            <h6 class="text-secondary mt-3">{{ $i18n.t('Static Connections') }}</h6>
            <b-table-simple v-if="status.static_connections && status.static_connections.length" small class="mb-0">
              <b-thead>
                <b-tr>
                  <b-th>{{ $i18n.t('Port') }}</b-th>
                  <b-th>{{ $i18n.t('Protocol') }}</b-th>
                  <b-th>{{ $i18n.t('Target') }}</b-th>
                  <b-th>{{ $i18n.t('Status') }}</b-th>
                </b-tr>
              </b-thead>
              <b-tbody>
                <b-tr v-for="(connection, index) in status.static_connections" :key="index">
                  <b-td class="text-monospace">{{ connection.local_port }}</b-td>
                  <b-td>{{ connection.local_proto }}</b-td>
                  <b-td class="text-monospace">{{ connection.remote_host }}:{{ connection.remote_port }}</b-td>
                  <b-td>
                    <b-badge :variant="connection.bound ? 'success' : 'danger'">
                      {{ connection.bound ? $i18n.t('open') : $i18n.t('closed') }}
                    </b-badge>
                  </b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
            <p v-else class="text-muted mb-0">{{ $i18n.t('No static connection configured for this connector.') }}</p>

            <h6 class="text-secondary mt-3">{{ $i18n.t('Dynamic Connections') }}</h6>
            <b-table-simple v-if="dynamicRemotes.length" small class="mb-0">
              <b-thead>
                <b-tr>
                  <b-th>{{ $i18n.t('Server Port') }}</b-th>
                  <b-th>{{ $i18n.t('Protocol') }}</b-th>
                  <b-th>{{ $i18n.t('Target') }}</b-th>
                </b-tr>
              </b-thead>
              <b-tbody>
                <b-tr v-for="(remote, index) in dynamicRemotes" :key="index">
                  <b-td class="text-monospace">{{ remote.local_host }}:{{ remote.local_port }}</b-td>
                  <b-td>{{ remote.local_proto }}</b-td>
                  <b-td class="text-monospace">{{ remote.remote_host }}:{{ remote.remote_port }}</b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
            <p v-else class="text-muted mb-0">{{ $i18n.t('No dynamic connection currently bound for this connector.') }}</p>
          </b-col>
        </b-row>

        <b-row v-if="siteNetwork" class="mt-3">
          <b-col md="6">
            <h6 class="text-secondary">{{ $i18n.t('Site networking: VLAN interfaces') }}</h6>
            <b-table-simple v-if="siteNetwork.interfaces && siteNetwork.interfaces.length" small class="mb-0">
              <b-thead>
                <b-tr>
                  <b-th>{{ $i18n.t('Interface') }}</b-th>
                  <b-th>{{ $i18n.t('Address') }}</b-th>
                  <b-th>{{ $i18n.t('State') }}</b-th>
                </b-tr>
              </b-thead>
              <b-tbody>
                <b-tr v-for="iface in siteNetwork.interfaces" :key="iface.name">
                  <b-td class="text-monospace">{{ iface.name }}</b-td>
                  <b-td class="text-monospace">{{ iface.cidr }}</b-td>
                  <b-td>
                    <b-badge :variant="siteNetworkVariant(iface.state)" :title="iface.error || ''">{{ iface.state }}</b-badge>
                    <small v-if="iface.error" class="d-block text-danger">{{ iface.error }}</small>
                  </b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
            <p v-else class="text-muted mb-0">{{ $i18n.t('No VLAN interface configured for this connector.') }}</p>
          </b-col>
          <b-col md="6">
            <h6 class="text-secondary">{{ $i18n.t('Site networking: static routes') }}</h6>
            <b-table-simple v-if="siteNetwork.routes && siteNetwork.routes.length" small class="mb-0">
              <b-thead>
                <b-tr>
                  <b-th>{{ $i18n.t('Destination') }}</b-th>
                  <b-th>{{ $i18n.t('Via') }}</b-th>
                  <b-th>{{ $i18n.t('State') }}</b-th>
                </b-tr>
              </b-thead>
              <b-tbody>
                <b-tr v-for="(route, index) in siteNetwork.routes" :key="index">
                  <b-td class="text-monospace">{{ route.destination }}</b-td>
                  <b-td class="text-monospace">{{ [route.gateway, route.interface].filter(v => v).join(' dev ') }}</b-td>
                  <b-td>
                    <b-badge :variant="siteNetworkVariant(route.state)" :title="route.error || ''">{{ route.state }}</b-badge>
                    <small v-if="route.error" class="d-block text-danger">{{ route.error }}</small>
                  </b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
            <p v-else class="text-muted mb-0">{{ $i18n.t('No static route configured for this connector.') }}</p>
          </b-col>
        </b-row>

        <b-row v-if="dhcpRelay.length || dnsServer.length" class="mt-3">
          <b-col v-if="dnsServer.length" md="5">
            <h6 class="text-secondary">{{ $i18n.t('Site networking: captive DNS') }}</h6>
            <b-table-simple small class="mb-0">
              <b-thead>
                <b-tr>
                  <b-th>{{ $i18n.t('Interface') }}</b-th>
                  <b-th>{{ $i18n.t('State') }}</b-th>
                  <b-th>{{ $i18n.t('Queries') }}</b-th>
                </b-tr>
              </b-thead>
              <b-tbody>
                <b-tr v-for="srv in dnsServer" :key="srv.interface">
                  <b-td class="text-monospace">{{ srv.interface }} ({{ srv.ip }})</b-td>
                  <b-td>
                    <b-badge :variant="srv.state === 'listening' ? 'success' : 'danger'" :title="srv.error || ''">{{ srv.state }}</b-badge>
                    <small v-if="srv.error" class="d-block text-danger">{{ srv.error }}</small>
                  </b-td>
                  <b-td>{{ srv.queries }}</b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
          </b-col>
          <b-col v-if="dhcpRelay.length">
            <h6 class="text-secondary">{{ $i18n.t('Site networking: DHCP relay') }}</h6>
            <b-table-simple small class="mb-0">
              <b-thead>
                <b-tr>
                  <b-th>{{ $i18n.t('Interface') }}</b-th>
                  <b-th>{{ $i18n.t('State') }}</b-th>
                  <b-th>{{ $i18n.t('Requests') }}</b-th>
                  <b-th>{{ $i18n.t('Replies') }}</b-th>
                  <b-th>{{ $i18n.t('Dropped') }}</b-th>
                </b-tr>
              </b-thead>
              <b-tbody>
                <b-tr v-for="relay in dhcpRelay" :key="relay.interface">
                  <b-td class="text-monospace">{{ relay.interface }} ({{ relay.ip }})</b-td>
                  <b-td>
                    <b-badge :variant="relay.state === 'listening' ? 'success' : 'danger'" :title="relay.error || relay.last_error || ''">{{ relay.state }}</b-badge>
                    <small v-if="relay.error || relay.last_error" class="d-block text-danger">{{ relay.error || relay.last_error }}</small>
                  </b-td>
                  <b-td>{{ relay.requests }}</b-td>
                  <b-td>{{ relay.replies }}</b-td>
                  <b-td>{{ relay.dropped }}</b-td>
                </b-tr>
              </b-tbody>
            </b-table-simple>
          </b-col>
        </b-row>
      </template>
      <p v-else-if="!isLoading" class="text-muted mb-0">{{ $i18n.t('Status unavailable.') }}</p>
    </div>

    <the-logs v-if="showLogs && logFiles.length" :id="id" :files="logFiles" />

    <b-modal v-model="showTerminalModal"
      :title="$i18n.t('Open Remote Terminal')"
      centered
    >
      <p>{{ $i18n.t('Enter the 6-digit code from the authenticator enrolled on this connector. The code is validated by the remote connector itself.') }}</p>
      <b-form @submit.prevent="authorizeTerminal">
        <b-form-input v-model="terminalCode" class="text-monospace"
          autofocus autocomplete="one-time-code" inputmode="numeric" maxlength="6" placeholder="123456" />
      </b-form>
      <template #modal-footer="{ hide }">
        <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
        <b-button variant="primary" :disabled="isTerminalLoading || terminalCode.length !== 6" @click="authorizeTerminal">
          {{ $i18n.t('Open Terminal') }}
        </b-button>
      </template>
    </b-modal>

    <b-modal v-model="showUpgradeModal"
      :title="$i18n.t('Upgrade Remote Connector')"
      centered
    >
      <p>{{ $i18n.t('The remote connector will point its PacketFence package repository at version {version}, upgrade its packetfence-pfconnector-remote package and restart. Network activity through this connector will be interrupted for a short period. Continue?', { version: status ? status.central_version : '' }) }}</p>
      <template #modal-footer="{ hide }">
        <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
        <b-button variant="warning" :disabled="isUpgrading" @click="upgrade">{{ $i18n.t('Upgrade') }}</b-button>
      </template>
    </b-modal>

    <b-modal v-model="showInstallModal"
      :title="$i18n.t('Install NTLM Authentication Services')"
      centered
    >
      <p>{{ $i18n.t('The connector host will install the packetfence-ntlm-auth-join-remote and packetfence-ntlm-auth-api-remote packages from the PacketFence repository of its own version (signature-verified). The connector itself is not restarted. Continue?') }}</p>
      <template #modal-footer="{ hide }">
        <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
        <b-button variant="primary" :disabled="isInstalling" @click="installNtlm">{{ $i18n.t('Install') }}</b-button>
      </template>
    </b-modal>

    <b-modal v-model="showSwitchModal"
      :title="$i18n.t('Make Another Host Active')"
      centered
    >
      <p>{{ $i18n.t('The virtual IP and the tunnel will move to {host} ({address}). This is a controlled failover: RADIUS is answered in degraded mode for a few seconds while the new host connects. Continue?', { host: switchTarget ? switchTarget.hostname : '', address: switchTarget ? switchTarget.address : '' }) }}</p>
      <template #modal-footer="{ hide }">
        <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
        <b-button variant="primary" :disabled="isSwitching" @click="switchActive">{{ $i18n.t('Make active') }}</b-button>
      </template>
    </b-modal>

    <b-modal v-model="showRestartModal"
      :title="$i18n.t('Restart Remote Connector')"
      centered
    >
      <p>{{ $i18n.t('The whole remote connector will be restarted (RADIUS, Fingerbank collector and tunnel included). Network activity through this connector will be interrupted for a short period. Continue?') }}</p>
      <template #modal-footer="{ hide }">
        <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
        <b-button variant="danger" :disabled="isRestarting" @click="restart">{{ $i18n.t('Restart') }}</b-button>
      </template>
    </b-modal>
  </div>
</template>
<script>
import { computed, onBeforeUnmount, onMounted, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from '../_api'
import TheLogs from './TheLogs'

export const props = {
  id: {
    type: String
  }
}

export const setup = (props, context) => {
  const { root: { $store } = {} } = context

  const status = ref(null)
  const errors = ref([])
  const isLoading = ref(false)
  const isRestarting = ref(false)
  const isUpgrading = ref(false)
  const showUpgradeModal = ref(false)
  const isTerminalLoading = ref(false)
  const showTerminalModal = ref(false)
  const terminalCode = ref('')
  const showRestartModal = ref(false)
  const lastRefresh = ref(null)
  const showLogs = ref(false)

  // The remote advertises its streamable logs in /system/info (log_files).
  // Connectors predating the feature (or with PFCONNECTOR_LOGS=false) omit
  // the field: no button, graceful degradation.
  const logFiles = computed(() => {
    const { system: { log_files: files } = {} } = status.value || {}
    return Array.isArray(files) ? files : []
  })

  // Result of the connector's last VLAN interface / static route reconcile
  // pass (/system/info site_network). Absent on connectors predating the
  // feature or before the first pass ran.
  const siteNetwork = computed(() => {
    const { system: { site_network: sn } = {} } = status.value || {}
    return sn || null
  })
  const dhcpRelay = computed(() => {
    const { system: { dhcp_relay: relay } = {} } = status.value || {}
    return Array.isArray(relay) ? relay : []
  })
  const dnsServer = computed(() => {
    const { system: { dns_server: srv } = {} } = status.value || {}
    return Array.isArray(srv) ? srv : []
  })
  const siteNetworkVariant = state => {
    switch (state) {
      case 'up':
      case 'applied':
        return 'success'
      case 'down':
        return 'warning'
      default:
        return 'danger'
    }
  }

  const refresh = () => {
    if (!props.id)
      return
    isLoading.value = true
    api.remoteStatus(props.id).then(response => {
      status.value = response
      errors.value = response.errors || []
      lastRefresh.value = (new Date()).toLocaleTimeString()
    }).catch(() => {
      errors.value = [i18n.t('Unable to fetch the remote connector status.')]
    }).finally(() => {
      isLoading.value = false
    })
  }

  // Delayed refreshes after an action, cleared on unmount.
  const refreshTimers = new Set()
  const scheduleRefresh = ms => {
    const timer = setTimeout(() => {
      refreshTimers.delete(timer)
      refresh()
    }, ms)
    refreshTimers.add(timer)
  }

  const escapeHtml = text => String(text).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]))

  const restart = () => {
    showRestartModal.value = false
    isRestarting.value = true
    api.remoteRestart(props.id).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Restart requested. The remote connector will reconnect shortly.') })
    }).catch(() => {
      $store.dispatch('notification/danger', { message: i18n.t('Unable to restart the remote connector.') })
    }).finally(() => {
      isRestarting.value = false
      scheduleRefresh(5000)
    })
  }

  // bound_remotes lists every reverse bind the server holds for this
  // connector, the static ones included; show only the dynamic ones here,
  // the static ones have their own table.
  const dynamicRemotes = computed(() => {
    const { bound_remotes: remotes = [], static_connections: statics = [] } = status.value || {}
    const staticKeys = new Set((statics || []).map(s => `${s.local_port}/${(s.local_proto || 'tcp').toLowerCase()}`))
    return (remotes || []).filter(r => !staticKeys.has(`${r.local_port}/${(r.local_proto || 'tcp').toLowerCase()}`))
  })

  // Listeners the connector opened on its host (local_binds in the system info).
  const localBinds = computed(() => {
    const { system: { local_binds: binds } = {} } = status.value || {}
    return Array.isArray(binds) ? binds : []
  })

  // connector-cache statistics (connector_cache in the system info).
  const cacheStats = computed(() => {
    const { system: { connector_cache: cc } = {} } = status.value || {}
    return cc || null
  })

  // NTLM authentication services on the connector host (host_packages in
  // the system info; install through the host's trigger file, asynchronous).
  const hostPackages = computed(() => {
    const { system: { host_packages: hp } = {} } = status.value || {}
    return (hp && hp.packages) ? hp : null
  })
  const ntlmInstalled = computed(() => {
    const hp = hostPackages.value
    return !!hp && hp.available && hp.packages.length > 0 && hp.packages.every(pkg => pkg.installed)
  })
  const installInProgress = computed(() => {
    const state = (hostPackages.value || {}).install_state || ''
    return /^(requested|installing)/.test(state)
  })
  const installStateClass = computed(() => {
    const state = (hostPackages.value || {}).install_state || ''
    if (/^failed/.test(state)) return 'text-danger'
    if (/^done/.test(state)) return 'text-success'
    return 'text-muted'
  })
  const isInstalling = ref(false)
  const showInstallModal = ref(false)
  let installPoll = null
  let switchPoll = null
  const installNtlm = () => {
    showInstallModal.value = false
    isInstalling.value = true
    api.remoteInstall(props.id, ['packetfence-ntlm-auth-join-remote']).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Install started on the connector host. The package state below updates as it progresses (details in the "install" log).') })
      // Follow the install more closely than the regular refresh for a while.
      let polls = 0
      if (installPoll) clearInterval(installPoll)
      installPoll = setInterval(() => {
        refresh()
        if (++polls >= 30 || ntlmInstalled.value) {
          clearInterval(installPoll)
          installPoll = null
        }
      }, 10000)
    }).catch(() => {
      $store.dispatch('notification/danger', { message: i18n.t('Unable to trigger the install on the connector host.') })
    }).finally(() => {
      isInstalling.value = false
      setTimeout(refresh, 3000)
    })
  }

  const upgrade = () => {
    showUpgradeModal.value = false
    isUpgrading.value = true
    api.remoteUpgrade(props.id).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Upgrade started. The remote connector will restart and report its new version once done (see conf/upgrade.log on the connector host for details).') })
    }).catch(() => {
      $store.dispatch('notification/danger', { message: i18n.t('Unable to trigger the upgrade of the remote connector.') })
    }).finally(() => {
      isUpgrading.value = false
      scheduleRefresh(10000)
    })
  }

  const openTerminal = () => {
    const { system: { terminal_totp: totpRequired } = {} } = status.value || {}
    if (totpRequired === false) {
      // The remote reports TOTP disabled (PFCONNECTOR_TERMINAL_TOTP=false):
      // no code to prompt for. Enforcement stays on the remote either way.
      requestTerminal()
      return
    }
    terminalCode.value = ''
    showTerminalModal.value = true
  }

  const authorizeTerminal = () => {
    if (terminalCode.value.length !== 6)
      return
    requestTerminal(terminalCode.value)
  }

  const requestTerminal = code => {
    isTerminalLoading.value = true
    api.terminalSession(props.id).then(session => {
      return api.terminalAuthorize(props.id, session.uuid, code).then(() => {
        showTerminalModal.value = false
        // noopener: the terminal page is authored by the remote host (served
        // sandboxed by the API); it must not get a handle on this window.
        window.open(`/api/v1/terminal/${encodeURIComponent(props.id)}/`, '_blank', 'noopener,noreferrer')
      })
    }).catch(error => {
      const { response: { data } = {} } = error || {}
      // Notifications render HTML: the remote's error text must be escaped.
      const detail = (typeof data === 'string' && data.trim()) ? ` (${escapeHtml(data.trim())})` : ''
      $store.dispatch('notification/danger', { message: i18n.t('Unable to open a terminal on the remote connector.') + detail })
    }).finally(() => {
      isTerminalLoading.value = false
    })
  }

  const formatBytes = bytes => {
    if (!bytes && bytes !== 0)
      return '-'
    const units = ['B', 'KB', 'MB', 'GB', 'TB']
    let value = bytes
    let unit = 0
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024
      unit++
    }
    return `${value.toFixed(1)} ${units[unit]}`
  }

  const formatPercent = value => {
    if (!value && value !== 0)
      return '-'
    return `${value.toFixed(1)}%`
  }

  const formatLoad = value => {
    if (!value && value !== 0)
      return '-'
    return value.toFixed(2)
  }

  // HA state reported by the master (the only host with a tunnel); peers are
  // the backups heard through their LAN heartbeats.
  const ha = computed(() => {
    const { system: { ha: state } = {} } = status.value || {}
    return (state && state.enabled) ? state : null
  })
  const haPeersAlive = computed(() => ((ha.value && ha.value.peers) || []).filter(peer => peer.alive))

  // Hand the VIP over to another host of the group (controlled failover).
  const isSwitching = ref(false)
  const showSwitchModal = ref(false)
  const switchTarget = ref(null)
  const switchActive = () => {
    showSwitchModal.value = false
    if (!switchTarget.value) return
    isSwitching.value = true
    const target = switchTarget.value.address
    api.remoteHaSwitch(props.id, target).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Switch started: {address} is taking the virtual IP. The panel updates once its tunnel is up.', { address: target }) })
    }).catch(error => {
      const { response: { data } = {} } = error || {}
      const detail = (typeof data === 'string' && data.trim()) ? ` (${data.trim()})` : ''
      $store.dispatch('notification/danger', { message: i18n.t('Unable to switch the active host.') + detail })
    }).finally(() => {
      // The old master's tunnel drops within a second; the new one is up a
      // few seconds later. Refresh a few times to follow.
      let polls = 0
      if (switchPoll) clearInterval(switchPoll)
      switchPoll = setInterval(() => {
        refresh()
        if (++polls >= 6) {
          clearInterval(switchPoll)
          switchPoll = null
          isSwitching.value = false
        }
      }, 5000)
    })
  }

  const formatDate = value => {
    if (!value)
      return '-'
    const date = new Date(value)
    return isNaN(date.getTime()) ? '-' : date.toLocaleString()
  }

  const formatUptime = seconds => {
    if (!seconds && seconds !== 0)
      return '-'
    const days = Math.floor(seconds / 86400)
    const hours = Math.floor((seconds % 86400) / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    return `${days}d ${hours}h ${minutes}m`
  }

  let refreshInterval = null
  onMounted(() => {
    refresh()
    refreshInterval = setInterval(refresh, 30000)
  })
  onBeforeUnmount(() => {
    if (refreshInterval)
      clearInterval(refreshInterval)
    if (installPoll)
      clearInterval(installPoll)
    if (switchPoll)
      clearInterval(switchPoll)
    refreshTimers.forEach(timer => clearTimeout(timer))
    refreshTimers.clear()
  })

  return {
    status,
    errors,
    isLoading,
    isRestarting,
    isUpgrading,
    dynamicRemotes,
    localBinds,
    cacheStats,
    hostPackages,
    ntlmInstalled,
    installInProgress,
    installStateClass,
    isInstalling,
    showInstallModal,
    installNtlm,
    showUpgradeModal,
    isTerminalLoading,
    showTerminalModal,
    terminalCode,
    showRestartModal,
    lastRefresh,
    showLogs,
    logFiles,
    siteNetwork,
    siteNetworkVariant,
    dhcpRelay,
    dnsServer,
    refresh,
    restart,
    upgrade,
    openTerminal,
    authorizeTerminal,
    ha,
    haPeersAlive,
    isSwitching,
    showSwitchModal,
    switchTarget,
    switchActive,
    formatDate,
    formatBytes,
    formatPercent,
    formatLoad,
    formatUptime
  }
}

// @vue/component
export default {
  name: 'the-status',
  inheritAttrs: false,
  components: {
    TheLogs
  },
  props,
  setup
}
</script>
