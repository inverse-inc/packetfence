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
      <template v-slot:cell(buttons)="{ item }">
        <span class="float-right text-nowrap">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="setDownload(item)">
            <icon class="mr-1" name="download"></icon> {{ $t('Download Certificate') }}
          </b-button>
        </span>
      </template>
    </b-table>
    <b-modal v-model="downloadCertModal" size="lg" @hidden="unsetDownload()"
     centered
     :hide-header-close="downloadCertLoading"
     :no-close-on-backdrop="downloadCertLoading"
     :no-close-on-esc="downloadCertLoading"
    >
      <template v-slot:modal-title>
        <h4>{{ $t('Download PKCS-12 Certificate') }}</h4>
        <b-form-text v-t="'Choose a password to encrypt the certificate.'" class="mb-0"></b-form-text>
      </template>
      <b-form-group class="mb-0">
        <pf-form-password :column-label="$t('Password')" :disabled="downloadCertLoading"
          v-model="downloadCertPassword"
          :text="$t('The certificate will be encrypted with this password.')"
          generate
        />
      </b-form-group>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="unsetDownload()">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" @click="doDownload()" :disabled="downloadCertLoading">
          <icon v-if="downloadCertLoading" class="mr-1" name="circle-notch" spin></icon> {{ $t('Download P12') }}
        </b-button>
      </template>
    </b-modal>
  </b-card>
</template>

<script>
import pfButtonService from '@/components/pfButtonService'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormPassword from '@/components/pfFormPassword'
import {
  columns,
  download
} from '../_config/pki/cert'

export default {
  name: 'pki-certs-list',
  components: {
    pfButtonService,
    pfEmptyTable,
    pfFormPassword
  },
  data () {
    return {
      columns, // ../_config/pki/cert
      profiles: [],
      certs: [],
      downloadCertLoading: false,
      downloadCertModal: false,
      downloadCertItem: undefined,
      downloadCertPassword: null
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
    setDownload (item) {
      this.downloadCertItem = item
      this.downloadCertModal = true
    },
    unsetDownload () {
      this.downloadCertModal = false
    },
    doDownload () {
      const { downloadCertItem: { ID: id, ca_name, profile_name, cn } = {}, downloadCertPassword: password = null } = this
      const filename = `${ca_name}-${profile_name}-${cn}.p12`
      this.downloadCertLoading = true
      Promise.resolve(download(id, password, filename)).then(() => {
        // copy password to clipboard
        try {
          navigator.clipboard.writeText(password).then(() => {
            this.$store.dispatch('notification/info', { message: this.$i18n.t('Certificate password copied to clipboard') })
          })
        } catch (e) {
          // noop
        }
      }).finally(() => {
        this.downloadCertItem = undefined
        this.downloadCertModal = false
        this.downloadCertLoading = false
      })
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
