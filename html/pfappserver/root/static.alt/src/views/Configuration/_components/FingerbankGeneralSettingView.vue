<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :isLoading="isLoading"
    :disabled="isLoading"
    :view="view"
    @save="save"
  >
    <template v-slot:header>
      <h4 class="mb-0">
        <span>{{ $t('Account information on api.fingerbank.org') }}</span>
        <b-button v-if="accountInfo" size="sm" variant="secondary" class="ml-2" :href="urlSSO" target="_blank">
          {{ $t('View complete account profile') }} <icon class="ml-1" name="external-link-alt"></icon>
        </b-button>
      </h4>
      <template v-if="accountInfo">
        <b-row class="mt-3 mb-1">
          <b-col sm="3" class="col-form-label pr-0">{{ $t('Username') }}</b-col>
          <b-col sm="auto" class="pt-1">{{ accountInfo.name }}</b-col>
        </b-row>
        <b-row class="my-1">
          <b-col sm="3" class="col-form-label pr-0">{{ $t('Account type') }}</b-col>
          <b-col sm="auto" class="pt-1" v-if="accountInfo.auth_type === 'github'">Github</b-col>
          <b-col sm="auto" class="pt-1" v-else-if="accountInfo.auth_type === 'local'">{{ $t('Corporate') }}</b-col>
          <b-col sm="auto" class="pt-1" v-else>{{ $t('Unknown') }}</b-col>
        </b-row>
        <b-row class="my-1">
          <b-col sm="3" class="col-form-label pr-0">{{ $t('Requests in the current hour') }}</b-col>
          <b-col sm="auto" class="pt-1">{{ accountInfo.timeframed_requests }}</b-col>
        </b-row>
      </template>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="isDisabled" :isLoading="isLoading" class="mr-1">
          <template>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="mr-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <pf-button-service service="fingerbank-collector" class="mr-1" restart start stop></pf-button-service>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonService from '@/components/pfButtonService'
import {
  view,
  validators
} from '../_config/fingerbank/'

export default {
  name: 'fingerbank-general-setting-view',
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonService
  },
  props: {
    formStoreName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      accountInfo: null
    }
  },
  computed: {
    meta () {
      return this.$store.getters[`${this.formStoreName}/$meta`]
    },
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    view () {
      return view(this.form, this.meta) // ../_config/fingerbank/
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_fingerbank/isGeneralSettingsLoading']
    },
    isDisabled () {
      return this.invalidForm || this.isLoading
    },
    urlSSO () {
      if (this.accountInfo) {
        return [
          'https://api.fingerbank.org:443/sso/login?',
          `username=${this.accountInfo.name}`,
          `key=${this.accountInfo.key}`,
          `redirect_url=/users/${this.accountInfo.id}`
        ].join('&')
      }
      return null
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_fingerbank/getAccountInfo').then(info => {
        this.accountInfo = info
      })
      this.$store.dispatch('$_fingerbank/optionsGeneralSettings').then(options => {
        this.$store.dispatch(`${this.formStoreName}/setOptions`, options)
      })
      this.$store.dispatch('$_fingerbank/getGeneralSettings').then(form => {
        this.$store.dispatch(`${this.formStoreName}/setForm`, form)
      })
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    save () {
      this.$store.dispatch('$_fingerbank/setGeneralSettings', this.form)
    }
  },
  created () {
    this.init()
  }
}
</script>
