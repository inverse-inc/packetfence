<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
      :isLoading="isLoading"
    >
      <template slot="pageHeader">
        <b-card-header>
          <h4 class="mb-3" v-t="'Authentication Sources'"></h4>
          <p v-t="'Define the authentication sources to let users access the captive portal or the admin Web interface.'"></p>
          <p v-t="'Each connection profile must be associated with one or multiple authentication sources while 802.1X connections use the ordered internal sources to determine which role to use. External sources are never used with 802.1X connections.'"></p>
        </b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-dropdown id="source-add-container" :text="$t('Add Source')" variant="outline-primary" class="my-2">
          <b-dropdown-header class="text-secondary">{{ $t('Internal') }}</b-dropdown-header>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'AD' } }">Active Directory</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'EAPTLS' } }">EAPTLS</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Htpasswd' } }">Htpasswd</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'HTTP' } }">HTTP</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Kerberos' } }">Kerberos</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'LDAP' } }">LDAP</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'POTD' } }">{{ $t('Password Of The Day') }}</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'RADIUS' } }">RADIUS</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'SAML' } }">SAML</b-dropdown-item>
          <b-dropdown-divider></b-dropdown-divider>
          <b-dropdown-header class="text-secondary">{{ $t('External') }}</b-dropdown-header>
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
          <b-dropdown-divider></b-dropdown-divider>
          <b-dropdown-header class="text-secondary">{{ $t('Exclusive') }}</b-dropdown-header>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'AdminProxy' } }">AdminProxy</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Blackhole' } }">Blackhole</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Eduroam' } }">Eduroam</b-dropdown-item>
          <b-dropdown-divider></b-dropdown-divider>
          <b-dropdown-header class="text-secondary">{{ $t('Billing') }}</b-dropdown-header>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'AuthorizeNet' } }">AuthorizeNet</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Mirapay' } }">Mirapay</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Paypal' } }">Paypal</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Stripe' } }">Stripe</b-dropdown-item>
        </b-dropdown>
      </template>
      <template slot="emptySearch">
        <pf-empty-table :isLoading="isLoading">{{ $t('No sources found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <pf-button-delete  v-if="!item.not_deletable" size="sm" variant="outline-danger" :disabled="isLoading" :confirm="$t('Delete Source?')" @on-delete="remove(item)" reverse/>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationAuthenticationSourcesListColumns as columns,
  pfConfigurationAuthenticationSourcesListFields as fields
} from '@/globals/pfConfigurationAuthenticationSources'

export default {
  name: 'AuthenticationSourcesList',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: {
        columns: columns,
        fields: fields,
        rowClickRoute (item, index) {
          return { name: 'source', params: { id: item.id } }
        },
        searchPlaceholder: this.$i18n.t('Search by name or description'),
        searchableOptions: {
          searchApiEndpoint: 'config/sources',
          defaultSortKeys: ['id'],
          defaultSearchCondition: {
            op: 'and',
            values: [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: null },
                { field: 'description', op: 'contains', value: null },
                { field: 'class', op: 'contains', value: null },
                { field: 'type', op: 'contains', value: null }
              ]
            }]
          },
          defaultRoute: { name: 'configuration/sources' },
          resultsFilter: (results) => results.filter(item => item.id !== 'local') // ignore 'local' source
        },
        searchableQuickCondition: (quickCondition) => {
          return {
            op: 'and',
            values: [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: quickCondition },
                { field: 'description', op: 'contains', value: quickCondition },
                { field: 'class', op: 'contains', value: quickCondition },
                { field: 'type', op: 'contains', value: quickCondition }
              ]
            }]
          }
        }
      }
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneAuthenticationSource', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_sources/deleteAuthenticationSource', item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>

<style lang="scss">
#source-add-container div[role="menu"] {
  overflow-x: hidden;
  overflow-y: scroll;
  max-height: 50vh;
}
</style>
