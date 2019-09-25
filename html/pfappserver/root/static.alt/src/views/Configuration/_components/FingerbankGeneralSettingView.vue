<template>
  <pf-config-view
    :isLoading="isLoading"
    :disabled="isLoading"
    :form="getForm"
    :model="form"
    :vuelidate="$v.form"
    @validations="formValidations = $event"
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
          <b-col sm="auto" class="pt-1" v-if="accountInfo.github_uid">Github</b-col>
          <b-col sm="auto" class="pt-1" v-else>Corporate</b-col>
        </b-row>
        <b-row class="my-1">
          <b-col sm="3" class="col-form-label pr-0">{{ $t('Requests in the current hour') }}</b-col>
          <b-col sm="auto" class="pt-1">{{ accountInfo.timeframed_requests }}</b-col>
        </b-row>
      </template>
    </template>
    <template v-slot:footer>
      <b-card-footer @mouseenter="$v.form.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import {
  pfConfigurationFingerbankGeneralSettingsViewFields as fields
} from '@/globals/configuration/pfConfigurationFingerbank'

const { validationMixin } = require('vuelidate')

export default {
  name: 'fingerbank-general-setting-view',
  mixins: [
    validationMixin
  ],
  components: {
    pfConfigView,
    pfButtonSave
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
      form: {}, // will be overloaded with the data from the store
      formValidations: {}, // will be overloaded with data from the pfConfigView
      options: {},
      accountInfo: null
    }
  },
  validations () {
    return {
      form: this.formValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isGeneralSettingsLoading`]
    },
    invalidForm () {
      return this.$v.form.$invalid || this.$store.getters[`${this.storeName}/isGeneralSettingsWaiting`]
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
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
      this.$store.dispatch(`${this.storeName}/getAccountInfo`).then(info => {
        this.accountInfo = info
      })
      this.$store.dispatch(`${this.storeName}/optionsGeneralSettings`).then(options => {
        this.options = options
        this.$store.dispatch(`${this.storeName}/getGeneralSettings`).then(form => {
          this.form = form
        })
      })
    },
    save () {
      this.$store.dispatch(`${this.storeName}/setGeneralSettings`, this.form)
    }
  },
  created () {
    this.init()
  }
}
</script>
