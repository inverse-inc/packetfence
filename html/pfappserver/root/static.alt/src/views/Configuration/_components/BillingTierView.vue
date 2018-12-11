<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="billingTier"
    :vuelidate="$v.billingTier"
    :isNew="isNew"
    :isClone="isClone"
    @validations="billingTierValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="id">{{ $t('Billing Tier') }} <strong v-text="id"></strong></span>
        <span v-else>{{ $t('New Billing Tier') }}</span>
      </h4>
    </template>
    <template slot="footer" is="b-card-footer" @mouseenter="$v.billingTier.$touch()">
      <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
      <pf-button-delete v-if="!isNew" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Billing Tier?')" @on-delete="remove()"/>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import {
  pfConfigurationBillingTierViewFields as fields,
  pfConfigurationBillingTierViewDefaults as defaults
} from '@/globals/pfConfigurationBillingTiers'
const { validationMixin } = require('vuelidate')

export default {
  name: 'BillingTierView',
  mixins: [
    validationMixin,
    pfMixinEscapeKey
  ],
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    isNew: { // from router
      type: Boolean,
      default: false
    },
    isClone: { // from router
      type: Boolean,
      default: false
    },
    id: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      billingTier: defaults(this), // will be overloaded with the data from the store
      billingTierValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      billingTier: this.billingTierValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    invalidForm () {
      return this.$v.billingTier.$invalid || this.$store.getters[`${this.storeName}/isWaiting`]
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    roles () {
      return this.$store.getters['config/rolesList']
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'billing_tiers' })
    },
    create () {
      this.$store.dispatch(`${this.storeName}/createBillingTier`, this.billingTier).then(response => {
        this.close()
      })
    },
    save () {
      this.$store.dispatch(`${this.storeName}/updateBillingTier`, this.billingTier).then(response => {
        this.close()
      })
    },
    remove () {
      this.$store.dispatch(`${this.storeName}/deleteBillingTier`, this.id).then(response => {
        this.close()
      })
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch(`${this.storeName}/getBillingTier`, this.id).then(data => {
        this.billingTier = Object.assign({}, data)
      })
    }
    this.$store.dispatch('config/getRoles')
  }
}
</script>
