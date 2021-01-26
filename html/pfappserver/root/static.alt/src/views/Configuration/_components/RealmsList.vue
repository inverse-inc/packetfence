<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-3">
        {{ $t('Realms') }}
        <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_default_domain_configuration" />
      </h4>
      <div class="alert alert-warning">{{ $t(`Any changes to the realms requires to restart radiusd-auth`) }}</div>
      <pf-button-service class="mr-1" service="radiusd-auth" restart start stop></pf-button-service>
    </b-card-header>

    <b-card class="m-3" v-for="tenant in tenants" :key="tenant.id">
      <h4 class="mb-3">{{ tenant.name }}</h4>

      <b-button class="mb-3" variant="outline-primary" :to="{ name: 'newRealm', params: { tenantId: tenant.id } }">{{ $t('New Realm') }}</b-button>

      <pf-table-sortable
        :items="realmsByTenant[tenant.id]"
        :fields="config.columns"
        hover
        striped
        @end="sort(tenant, $event)"
        @row-clicked="onRowClick(tenant, $event)"
      >
        <template v-slot:empty>
          <pf-empty-table :isLoading="isLoading" :text="$t('Click the button to create a new Realm for this Tenant.')">{{ $t('No realms found for this tenant') }}</pf-empty-table>
        </template>
        <template v-slot:cell(radius_auth)="{ radius_auth: value }">
          <span v-if="value.length === 0">&nbsp;<!-- hide empty --></span>
          <b-badge v-else v-for="(item, index) in value" :key="index" class="ml-2" variant="secondary">{{ item }}</b-badge>
        </template>

        <template v-slot:cell(radius_acct)="{ radius_acct: value }">
          <span v-if="value.length === 0">&nbsp;<!-- hide empty --></span>
          <b-badge v-else v-for="(item, index) in value" :key="index" class="ml-2" variant="secondary">{{ item }}</b-badge>
        </template>
        <template v-slot:cell(portal_strip_username)="{ portal_strip_username: value }">
          <icon name="circle" :class="{ 'text-success': value === 'enabled', 'text-danger': value === 'disabled' }"
            v-b-tooltip.hover.left.d300 :title="$t(value)"></icon>
        </template>
        <template v-slot:cell(admin_strip_username)="{ admin_strip_username: value }">
          <icon name="circle" :class="{ 'text-success': value === 'enabled', 'text-danger': value === 'disabled' }"
            v-b-tooltip.hover.left.d300 :title="$t(value)"></icon>
        </template>
        <template v-slot:cell(radius_strip_username)="{ radius_strip_username: value }">
          <icon name="circle" :class="{ 'text-success': value === 'enabled', 'text-danger': value === 'disabled' }"
            v-b-tooltip.hover.left.d300 :title="$t(value)"></icon>
        </template>
        <template v-slot:cell(buttons)="item">
          <span class="float-right text-nowrap">
            <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Realm?')" @on-delete="remove(tenant, item)" reverse/>
            <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(tenant, item)">{{ $t('Clone') }}</b-button>
          </span>
        </template>
      </pf-table-sortable>
    </b-card>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonService from '@/components/pfButtonService'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfTableSortable from '@/components/pfTableSortable'
import { config } from '../_config/realm'

export default {
  name: 'realms-list',
  components: {
    pfButtonDelete,
    pfButtonService,
    pfButtonHelp,
    pfEmptyTable,
    pfTableSortable
  },
  data () {
    return {
      config: config(this)
    }
  },
  computed: {
    tenants () {
      const { id } = this.$store.state.session.tenant
      if (id) // single-tenant mode
        return this.$store.state.session.tenants.filter(tenant => +tenant.id === +id)
      else // multi-tenant mode
        return this.$store.state.session.tenants
    },
    isLoading () {
      return this.$store.getters['$_realms/isLoading']
    },
    realmsByTenant () {
      this.tenants.map(tenant => this.$store.dispatch('$_realms/allByTenant', tenant.id))
      return this.$store.getters['$_realms/tenants']
    }
  },
  methods: {
    clone (tenant, realm) {
      this.$router.push({ name: 'cloneRealm', params: { tenantId: tenant.id, id: realm.id } })
    },
    remove (tenant, realm) {
      this.$store.dispatch('$_realms/deleteRealm', { tenantId: tenant.id, id: realm.id }).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    },
    sort (tenant, event) {
      let realms = this.realmsByTenant[tenant.id]
      const { oldIndex, newIndex } = event // shifted, not swapped
      const tmp = realms[oldIndex]
      if (oldIndex > newIndex) {
        // shift down (not swapped)
        for (let i = oldIndex; i > newIndex; i--) {
          realms[i] = realms[i - 1]
        }
      } else {
        // shift up (not swapped)
        for (let i = oldIndex; i < newIndex; i++) {
          realms[i] = realms[i + 1]
        }
      }
      realms[newIndex] = tmp
      this.$store.dispatch('$_realms/sortRealms', { tenantId: tenant.id, items: realms.map(realm => realm.id) }).then(() => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Realms resorted.') })
      })
    },
    onRowClick (tenant, realm) {
      this.$router.push({ name: 'realm', params: { tenantId: tenant.id, id: realm.id } })
    }
  }
}
</script>
