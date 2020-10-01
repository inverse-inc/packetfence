<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">{{ $t('Certificates') }}</h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-dropdown :text="$t('New Certificate')" variant="outline-primary" :disabled="profiles.length === 0">
          <b-dropdown-header>{{ $t('Choose Certificate Authority - Template') }}</b-dropdown-header>
          <b-dropdown-item v-for="profile in sortedProfiles" :key="profile.ID" :to="{ name: 'newPkiCert', params: { profile_id: profile.ID } }">{{ profile.ca_name }} - {{ profile.name }}</b-dropdown-item>
        </b-dropdown>
        <pf-button-service service="pfpki" class="ml-1" restart start stop :disabled="isLoading" @start="init" @restart="init"></pf-button-service>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No certificates found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(ca_name)="item">
        <router-link :to="{ name: 'pkiCa', params: { id: item.ca_id } }">{{ item.ca_name }}</router-link>
      </template>
      <template v-slot:cell(profile_name)="item">
        <router-link :to="{ name: 'pkiProfile', params: { id: item.profile_id } }">{{ item.profile_name }}</router-link>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <pf-button-pki-cert-download size="sm" variant="outline-primary" class="mr-1"
            :disabled="isLoading" :cert="item" :download="download"
          />
          <b-button v-if="item.mail" size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="email(item)">{{ $t('Email') }}</b-button>
          <pf-button-pki-cert-revoke size="sm" variant="outline-danger" class="mr-1"
            :disabled="isLoading" :cert="item" :revoke="revoke"
          />
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonPkiCertDownload from '@/components/pfButtonPkiCertDownload'
import pfButtonPkiCertRevoke from '@/components/pfButtonPkiCertRevoke'
import pfButtonService from '@/components/pfButtonService'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  config,
  revoke,
  download
} from '../_config/pki/cert'

export default {
  name: 'pki-certs-list',
  components: {
    pfButtonPkiCertDownload,
    pfButtonPkiCertRevoke,
    pfButtonService,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this),
      revoke, // ../_config/pki/cert
      download // ../_config/pki/cert
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_pkis/isCertLoading']
    },
    profiles () {
      return this.$store.getters['$_pkis/profiles'] || []
    },
    sortedProfiles () {
      return Array.prototype.slice.call(this.profiles).sort((a, b) => {
        return (a.ca_name === b.ca_name)
          ? a.name.localeCompare(b.name)
          : a.ca_name.localeCompare(b.ca_name)
      }) // sort profiles by 'name'
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_pkis/allProfiles')
    },
    clone (item) {
      this.$router.push({ name: 'clonePkiCert', params: { id: item.ID } })
    },
    email (item) {
      const { ID, mail } = item
      if (mail) {
        this.$store.dispatch('$_pkis/emailCert', ID).then(response => {
          this.$store.dispatch('notification/info', { message: this.$i18n.t('Certificate <code>{cn}</code> emailed to <code>{mail}</code>.', item) })
        }).catch(e => {
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Could not email certificate <code>{cn}</code> to <code>{mail}</code>: ', item) + e })
        })
      }
    }
  },
  created () {
    this.init()
  }
}
</script>
