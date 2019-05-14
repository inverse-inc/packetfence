<template>
  <div>
    <b-card no-body>
      <b-card-header>
        <h4 class="mb-3" v-t="'Authentication Sources'"></h4>
        <p v-t="'Define the authentication sources to let users access the captive portal or the admin Web interface.'"></p>
        <p class="mb-0" v-t="'Each connection profile must be associated with one or multiple authentication sources while 802.1X connections use the ordered internal sources to determine which role to use. External sources are never used with 802.1X connections.'"></p>
      </b-card-header>

      <b-card class="m-3">
        <h4 class="mb-3">{{ $t('Internal Sources') }}</h4>
        <b-dropdown class="mb-3" :text="$t('New internal source')" variant="outline-primary">
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'AD' } }">Active Directory</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Authorization' } }">Authorization</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'EAPTLS' } }">EAPTLS</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Htpasswd' } }">Htpasswd</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'HTTP' } }">HTTP</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Kerberos' } }">Kerberos</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'LDAP' } }">LDAP</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Potd' } }">{{ $t('Password Of The Day') }}</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'RADIUS' } }">RADIUS</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'SAML' } }">SAML</b-dropdown-item>
        </b-dropdown>
        <pf-table-sortable
          :items="internalSources"
          :fields="config.columns"
          @row-clicked="onRowClick"
          hover
          striped
          @end="sort(internalSources, $event)"
        >
          <template slot="empty">
            <pf-empty-table :isLoading="isLoading" :text="$t('Click the button to define a new source.')">{{ $t('No internal sources defined') }}</pf-empty-table>
          </template>
          <template slot="buttons" slot-scope="{ item }">
            <span class="float-right text-nowrap">
              <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Source?')" @on-delete="remove(item)" reverse/>
              <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
            </span>
          </template>
        </pf-table-sortable>
      </b-card>

      <b-card class="m-3">
        <h4 class="mb-3">{{ $t('External Sources') }}</h4>
        <b-dropdown class="mb-3" :text="$t('New external source')" variant="outline-primary">
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Clickatell' } }">Clickatell</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Email' } }">Email</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Facebook' } }">Facebook</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Github' } }">Github</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Google' } }">Google</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Instagram' } }">Instagram</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Kickbox' } }">Kickbox</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'LinkedIn' } }">LinkedIn</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Null' } }">{{ $t('Null') }}</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'OpenID' } }">OpenID</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Pinterest' } }">Pinterest</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'SMS' } }">SMS</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'SponsorEmail' } }">{{ $t('Sponsor') }}</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Twilio' } }">Twilio</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Twitter' } }">Twitter</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'WindowsLive' } }">WindowsLive</b-dropdown-item>
        </b-dropdown>
        <pf-table-sortable
          :items="externalSources"
          :fields="config.columns"
          @row-clicked="onRowClick"
          hover
          striped
          @end="sort(externalSources, $event)"
        >
          <template slot="empty">
            <pf-empty-table :isLoading="isLoading" :text="$t('Click the button to define a new source.')">{{ $t('No external sources defined') }}</pf-empty-table>
          </template>
          <template slot="buttons" slot-scope="{ item }">
            <span class="float-right text-nowrap">
              <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Source?')" @on-delete="remove(item)" reverse/>
              <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
            </span>
          </template>
        </pf-table-sortable>
      </b-card>

      <b-card class="m-3">
        <h4 class="mb-3">{{ $t('Exclusive Sources') }}</h4>
        <b-dropdown class="mb-3" :text="$t('New exclusive source')" variant="outline-primary">
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'AdminProxy' } }">AdminProxy</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Blackhole' } }">Blackhole</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Eduroam' } }">Eduroam</b-dropdown-item>
        </b-dropdown>
        <pf-table-sortable
          :items="exclusiveSources"
          :fields="config.columns"
          @row-clicked="onRowClick"
          hover
          striped
          @end="sort(exclusiveSources, $event)"
        >
          <template slot="empty">
            <pf-empty-table :isLoading="isLoading" :text="$t('Click the button to define a new source.')">{{ $t('No exclusive source defined') }}</pf-empty-table>
          </template>
          <template slot="buttons" slot-scope="{ item }">
            <span class="float-right text-nowrap">
              <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Source?')" @on-delete="remove(item)" reverse/>
              <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
            </span>
          </template>
        </pf-table-sortable>
      </b-card>

      <b-card class="m-3">
        <h4 class="mb-3">{{ $t('Billing Sources') }}</h4>
        <b-dropdown class="mb-3" :text="$t('New billing source')" variant="outline-primary">
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'AuthorizeNet' } }">AuthorizeNet</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Mirapay' } }">Mirapay</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Paypal' } }">Paypal</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Stripe' } }">Stripe</b-dropdown-item>
        </b-dropdown>
        <pf-table-sortable
          :items="billingSources"
          :fields="config.columns"
          @row-clicked="onRowClick"
          hover
          striped
          @end="sort(billingSources, $event)"
        >
          <template slot="empty">
            <pf-empty-table :isLoading="isLoading" :text="$t('Click the button to define a new source.')">{{ $t('No billing sources defined') }}</pf-empty-table>
          </template>
          <template slot="buttons" slot-scope="{ item }">
            <span class="float-right text-nowrap">
              <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Source?')" @on-delete="remove(item)" reverse/>
              <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
            </span>
          </template>
        </pf-table-sortable>
      </b-card>

    </b-card>
  </div>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfTableSortable from '@/components/pfTableSortable'
import {
  pfConfigurationAuthenticationSourceListConfig as config
} from '@/globals/configuration/pfConfigurationAuthenticationSources'

export default {
  name: 'AuthenticationSourcesList',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable,
    pfTableSortable
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      config: config(this),
      sources: [],
      draggingRow: null,
      draggingRowIndex: null
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    internalSources () {
      return this.sources.filter(source => source.id !== 'local' && source.class === 'internal')
    },
    externalSources () {
      return this.sources.filter(source => source.id !== 'local' && source.class === 'external')
    },
    exclusiveSources () {
      return this.sources.filter(source => source.id !== 'local' && source.class === 'exclusive')
    },
    billingSources () {
      return this.sources.filter(source => source.id !== 'local' && source.class === 'billing')
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`${this.storeName}/all`).then(sources => {
        this.sources = sources
      })
    },
    clone (item) {
      this.$router.push({ name: 'cloneAuthenticationSource', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteAuthenticationSource`, item.id).then(response => {
        this.$router.go() // reload
      })
    },
    sort (items, event) {
      const { oldIndex, newIndex } = event // shifted, not swapped
      const tmp = items[oldIndex]
      if (oldIndex > newIndex) {
        // shift down (not swapped)
        for (let i = oldIndex; i > newIndex; i--) {
          items[i] = items[i - 1]
        }
      } else {
        // shift up (not swapped)
        for (let i = oldIndex; i < newIndex; i++) {
          items[i] = items[i + 1]
        }
      }
      items[newIndex] = tmp
      this.sources = [ // rebuild sources
        ...this.sources.filter(_item => !items.map(item => item.id).includes(_item.id)), // all but sorted items
        ...items // sorted items
      ]
      this.$store.dispatch(`${this.storeName}/sortAuthenticationSources`, items.map(item => item.id)).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Authentication sources resorted.') })
      })
    },
    onRowClick (item, index) {
      this.$router.push(this.config.rowClickRoute(item, index))
    }
  },
  created () {
    this.init()
  }
}
</script>
