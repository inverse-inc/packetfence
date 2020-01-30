<template>
  <b-card>
    <h4 class="mb-3">{{ $t('Certificates') }}</h4>
    <b-row align-h="end" align-v="start" class="mb-3">
      <b-col>
        <b-dropdown :text="$t('New Certificate')" variant="outline-primary" :disabled="profiles.length === 0">
          <b-dropdown-header>{{ $t('Choose Certificate Authority - Profile') }}</b-dropdown-header>
          <b-dropdown-item v-for="profile in profiles" :key="profile.ID" :to="{ name: 'newPkiCert', params: { profile_id: profile.ID } }">{{ profile.ca_name }} - {{ profile.name }}</b-dropdown-item>
        </b-dropdown>
        <pf-button-service service="pfpki" class="ml-1" restart start stop :disabled="isLoading" @start="init" @restart="init"></pf-button-service>
      </b-col>
    </b-row>
    <b-table
      :items="certs"
      :fields="columns"
      @row-clicked="onRowClick"
      hover
      striped
    >
      <template v-slot:empty>
        <pf-empty-table :isLoading="isLoading" :text="$t('Click the button to define a new Certificate.')">{{ $t('No certificates defined') }}</pf-empty-table>
      </template>
      <template v-slot:cell(ca_profile)="{ item }">
        <router-link :to="{ name: 'pkiCa', params: { id: item.ca_id } }">{{ item.ca_name }}</router-link> - <router-link :to="{ name: 'pkiProfile', params: { id: item.profile_id } }">{{ item.profile_name }}</router-link>
      </template>
      <template v-slot:cell(buttons)="{ item }">
        <span class="float-right text-nowrap">
          <pf-button-pki-cert-revoke size="sm" variant="outline-danger" class="mr-1"
            :disabled="isLoading" :cert="item" :revoke="revoke"
          />
          <pf-button-pki-cert-download size="sm" variant="outline-primary" class="mr-1"
            :disabled="isLoading" :cert="item" :download="download"
          />
          <b-button v-if="item.mail" size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="email(item)">
            <icon class="mr-1" name="at"></icon> {{ $t('Email') }}
          </b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
    </b-table>
  </b-card>
</template>

<script>
import pfButtonPkiCertDownload from '@/components/pfButtonPkiCertDownload'
import pfButtonPkiCertRevoke from '@/components/pfButtonPkiCertRevoke'
import pfButtonService from '@/components/pfButtonService'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  columns,
  revoke,
  download
} from '../_config/pki/cert'

export default {
  name: 'pki-certs-list',
  components: {
    pfButtonPkiCertDownload,
    pfButtonPkiCertRevoke,
    pfButtonService,
    pfEmptyTable
  },
  data () {
    return {
      columns, // ../_config/pki/cert
      revoke, // ../_config/pki/cert
      download, // ../_config/pki/cert
      profiles: [],
      certs: []
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_pkis/isCertLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_pkis/allProfiles').then(profiles => {
        this.profiles = profiles.sort((a, b) => { // sort profiles
          return (a.ca_name === b.ca_name)
            ? a.name.localeCompare(b.name)
            : a.ca_name.localeCompare(b.ca_name)
        })
      })
      this.$store.dispatch('$_pkis/allCerts').then(certs => {
        this.certs = certs
      })
    },
    clone (item) {
      this.$router.push({ name: 'clonePkiCert', params: { id: item.ID } })
    },
    email (item) {
      const { cn, mail } = item
      if (mail) {
        this.$store.dispatch('$_pkis/emailCert', cn).then(response => {
          this.$store.dispatch('notification/info', { message: this.$i18n.t('Certificate <code>{cn}</code> emailed to <code>{mail}</code>.', item) })
        }).catch(e => {
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Could not email certificate <code>{cn}</code> to <code>{mail}</code>.<br/>Reason: ', item) + e })
        })
      }
    },
    onRowClick (item) {
      this.$router.push({ name: 'pkiCert', params: { id: item.ID } })
    }
  },
  created () {
    this.init()
  }
}
</script>
