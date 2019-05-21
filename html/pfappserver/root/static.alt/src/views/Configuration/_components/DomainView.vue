<template>
  <pf-config-view
    :isLoading="isLoading"
    :disabled="isLoading"
    :isDeletable="isDeletable"
    :form="getForm"
    :model="form"
    :vuelidate="$v.form"
    :isNew="isNew"
    :isClone="isClone"
    @validations="formValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Domain {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Domain {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Domain') }}</span>
      </h4>
    </template>
    <template slot="footer">
      <b-card-footer @mouseenter="$v.form.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew && !ctrlKey">{{ $t('Create & Join') }}</template>
          <template v-else-if="isNew && ctrlKey">{{ $t('Create') }}</template>
          <template v-else-if="isClone && !ctrlKey">{{ $t('Clone & Join') }}</template>
          <template v-else-if="isClone && ctrlKey">{{ $t('Clone') }}</template>
          <template v-else-if="!isNew && !isClone && !ctrlKey">{{ $t('Save') }}</template>
          <template v-else>{{ $t('Save & Join') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Domain?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfMixinCtrlKey from '@/components/pfMixinCtrlKey'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import {
  pfConfigurationDefaultsFromMeta as defaults
} from '@/globals/configuration/pfConfiguration'
import {
  pfConfigurationDomainViewFields as fields
} from '@/globals/configuration/pfConfigurationDomains'
const { validationMixin } = require('vuelidate')

export default {
  name: 'DomainView',
  mixins: [
    validationMixin,
    pfMixinCtrlKey,
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
      form: {}, // will be overloaded with the data from the store
      formValidations: {}, // will be overloaded with data from the pfConfigView
      options: {}
    }
  },
  validations () {
    return {
      form: this.formValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    invalidForm () {
      return this.$v.form.$invalid || this.$store.getters[`${this.storeName}/isWaiting`]
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    isDeletable () {
      if (this.isNew || this.isClone || ('not_deletable' in this.form && this.form.not_deletable)) {
        return false
      }
      return true
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`${this.storeName}/options`, this.id).then(options => {
        this.options = options
        if (this.id) {
          // existing
          this.$store.dispatch(`${this.storeName}/getDomain`, this.id).then(form => {
            if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
            this.form = form
          })
        } else {
          // new
          this.form = defaults(options.meta) // set defaults
        }
      })
    },
    close () {
      this.$router.push({ name: 'domains' })
    },
    clone () {
      this.$router.push({ name: 'cloneDomain' })
    },
    create () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/createDomain`, this.form).then(response => {
        if (!ctrlKey) {
          this.$router.push({ name: 'domains', params: { autoJoinDomain: this.form } })
        } else {
          this.$router.push({ name: 'domain', params: { id: this.form.id } })
        }
      })
    },
    save () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/updateDomain`, this.form).then(response => {
        if ((this.isNew && !ctrlKey) || (this.isClone && !ctrlKey) || (!this.isNew && !this.isClone && ctrlKey)) {
          this.$router.push({ name: 'domains', params: { autoJoinDomain: this.form } })
        }
      })
    },
    remove () {
      this.$store.dispatch(`${this.storeName}/deleteDomain`, this.id).then(response => {
        this.close()
      })
    }
  },
  created () {
    this.init()
  },
  watch: {
    id: {
      handler: function (a, b) {
        this.init()
      }
    },
    isClone: {
      handler: function (a, b) {
        this.init()
      }
    }
  }
}
</script>
