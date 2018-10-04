
<template>
  <b-form @submit.prevent="isNew? create() : save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">
          <span v-if="id">{{ $t('Domain') }} <strong v-text="id"></strong></span>
          <span v-else>{{ $t('New Domain') }}</span>
        </h4>
      </b-card-header>
      <div class="card-body">
        <pf-form-input v-if="isNew" v-model="domain.id"
          :column-label="$t('Identifier')"
          :validation="$v.domain.id"
          :text="$t('Specify a unique identifier for your configuration.<br/>This doesn\'t have to be related to your domain')"/>
        <pf-form-input v-model="domain.workgroup"
          :column-label="$t('Workgroup')"
          :validation="$v.domain.workgroup"/>
        <pf-form-input v-model="domain.dns_name"
          :column-label="$t('DNS name of the domain')"
          :validation="$v.domain.dns_name"
          :text="$t('The DNS name (FQDN) of the domain.')"/>
        <pf-form-input v-model="domain.server_name"
          :column-label="$t('This server\'s name')"
          :validation="$v.domain.server_name"
          :text="$t('This server\'s name (account name) in your Active Directory. Use \'%h\' to automatically use this server hostname')"/>
        <pf-form-input v-model="domain.sticky_dc"
          :column-label="$t('Sticky DC')"
          :validation="$v.domain.sticky_dc"
          :text="$t('This is used to specify a sticky domain controller to connect to. If not specified, default \'*\' will be used to connect to any available domain controller')"/>
        <pf-form-input v-model="domain.ad_server"
          :column-label="$t('Active Directory server')"
          :validation="$v.domain.ad_server"
          :text="$t('The IP address or DNS name of your Active Directory server')"/>
          <!-- dns_servers -->
        <pf-form-input v-model="domain.bind_dn"
          :column-label="$t('Username')"
          :text="$t('The username of a Domain Admin to use to join the server to the domain')"/>
        <pf-form-input v-model="domain.bind_pass" type="password"
          :column-label="$t('Password')"
          :text="$t('The password of a Domain Admin to use to join the server to the domain. Will not be stored permanently and is only used while joining the domain.')"/>
      </div>
      <b-card-footer @mouseenter="$v.domain.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
        <pf-button-delete v-if="!isNew" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Domain?')" @on-delete="deleteDomain()"/>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfFormInput from '@/components/pfFormInput'
import pfFormRow from '@/components/pfFormRow'
import { isFQDN } from '@/globals/pfValidators'
const { validationMixin } = require('vuelidate')
const { required, alphaNum } = require('vuelidate/lib/validators')

export default {
  name: 'DomainView',
  components: {
    pfButtonSave,
    pfButtonDelete,
    pfFormRow,
    pfFormInput
  },
  mixins: [
    validationMixin
  ],
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    id: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      domain: { // will be overloaded with the data from the store
        id: null,
        ad_server: '%h'
      }
    }
  },
  validations: {
    domain: {
      id: { required, alphaNum },
      workgroup: { required },
      dns_name: { required, isFQDN },
      server_name: { required },
      sticky_dc: { required },
      ad_server: { required }
    }
  },
  computed: {
    isNew () {
      return this.id === null
    },
    isLoading () {
      return this.$store.getters['$_domains/isLoading']
    },
    invalidForm () {
      return this.$v.domain.$invalid || this.$store.getters['$_domains/isWaiting']
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'domains' })
    },
    create () {
      this.$store.dispatch('$_domains/createDomain', this.domain).then(response => {
        this.close()
      })
    },
    save () {
      this.$store.dispatch('$_domains/updateDomain', this.domain).then(response => {
        this.close()
      })
    },
    deleteDomain () {
      this.$store.dispatch('$_domains/deleteDomain', this.id).then(response => {
        this.close()
      })
    },
    onKeyup (event) {
      switch (event.keyCode) {
        case 27: // escape
          this.close()
      }
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_domains/getDomain', this.id).then(data => {
        this.domain = Object.assign({}, data)
      })
    }
  },
  mounted () {
    document.addEventListener('keyup', this.onKeyup)
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onKeyup)
  }
}
</script>
