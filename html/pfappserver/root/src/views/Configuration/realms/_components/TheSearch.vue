<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-flex align-items-center mb-0">
        {{ $t('Realms') }}
        <base-button-help class="text-black-50 ml-1" url="PacketFence_Installation_Guide.html#_default_domain_configuration" />
      </h4>
    </b-card-header>
    <div class="card-body">
      <div class="alert alert-warning">{{ $t(`Any changes to the realms requires to restart radiusd-auth`) }}</div>
      <base-search :use-search="useSearch">
        <base-button-service
          service="radiusd-auth" restart start stop
          class="ml-1" />
      </base-search>

      <b-card v-for="(tenant, index) in tenantsRealms" :key="tenant.id"
        :class="{ 'mt-3': index > 0 }">
        <h4 class="mb-3">{{ tenant.name }}</h4>
        <b-button variant="outline-primary" @click="goToNew({ tenantId: tenant.id })">{{ $t('New Realm') }}</b-button>
        <the-table class="mt-3" :tenantId="tenant.id"
          :isLoading="isLoading"
          :items="tenant.items"
          :columns="columns"
          :visibleColumns="visibleColumns"
          @reSearch="reSearch"
          @setColumns="setColumns"
        />
      </b-card>
    </div>
  </b-card>
</template>
<script>
import {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseButtonService,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableSortable
} from '@/components/new/'
import pfEmptyTable from '@/components/pfEmptyTable'
import TheTable from './TheTable'

const components = {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseButtonService,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableSortable,
  pfEmptyTable,
  TheTable
}

import { computed, toRefs } from '@vue/composition-api'
import { useRouter, useSearch } from '../_composables/useCollection'

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  const router = useRouter($router)

  const search = useSearch()
  const {
    items
  } = toRefs(search)

  const singleTenant = computed(() => $store.state.session.tenant)
  const tenants = computed(() => ((singleTenant.value)
    ? $store.state.session.tenants.filter(tenant => +tenant.id === +singleTenant.value.id) // single-tenant mode
    : $store.state.session.tenants // multi-tenant mode
  ))
  const tenantsRealms = computed(() => {
    return tenants.value.map(tenant => {
      return { ...tenant, items: items.value.filter(item => +item.tenant_id === +tenant.id ) }
    })
  })

  return {
    useSearch,
    ...router,
    ...toRefs(search),
    tenantsRealms
  }
}

// @vue/component
export default {
  name: 'the-search',
  inheritAttrs: false,
  components,
  setup
}
</script>




















<!--


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
          <pf-empty-table :is-loading="isLoading" :text="$t('Click the button to create a new Realm for this Tenant.')">{{ $t('No realms found for this tenant') }}</pf-empty-table>
        </template>
        <template v-slot:cell(radius_auth)="{ radius_auth: value }">
          <span v-if="value.length === 0">&nbsp;</span>
          <b-badge v-else v-for="(item, index) in value" :key="index" class="ml-2" variant="secondary">{{ item }}</b-badge>
        </template>

        <template v-slot:cell(radius_acct)="{ radius_acct: value }">
          <span v-if="value.length === 0">&nbsp;</span>
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
import { config } from '../../_config/realm'

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

-->