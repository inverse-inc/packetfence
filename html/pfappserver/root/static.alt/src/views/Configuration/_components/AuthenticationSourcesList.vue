<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header>
          <h4 class="mb-3" v-t="'Authentication Sources'"></h4>
          <p v-t="'Define the authentication sources to let users access the captive portal or the admin Web interface.'"></p>
          <p class="mb-0" v-t="'Each connection profile must be associated with one or multiple authentication sources while 802.1X connections use the ordered internal sources to determine which role to use. External sources are never used with 802.1X connections.'"></p>
        </b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-dropdown :text="$t('New Source')" variant="outline-primary">
          <b-dropdown-header class="text-secondary">{{ $t('Internal') }}</b-dropdown-header>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'AD' } }">Active Directory</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'EAPTLS' } }">EAPTLS</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Htpasswd' } }">Htpasswd</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'HTTP' } }">HTTP</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Kerberos' } }">Kerberos</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'LDAP' } }">LDAP</b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newAuthenticationSource', params: { sourceType: 'Potd' } }">{{ $t('Password Of The Day') }}</b-dropdown-item>
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
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No sources found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Source?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
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
  pfConfigurationAuthenticationSourceListConfig as config
} from '@/globals/configuration/pfConfigurationAuthenticationSources'

export default {
  name: 'AuthenticationSourcesList',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
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
      config: config(this)
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneAuthenticationSource', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteAuthenticationSource`, item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
