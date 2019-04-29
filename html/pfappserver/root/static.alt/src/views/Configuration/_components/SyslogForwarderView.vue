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
    @validations="setValidations($event)"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="d-inline mb-0">
        <span v-if="!isNew && !isClone">{{ $t('Syslog Entry {id}', { id: id }) }}</span>
        <span v-else-if="isClone">{{ $t('Clone Syslog Entry {id}', { id: id }) }}</span>
        <span v-else>{{ $t('New Syslog Entry') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="syslogForwarderType"></b-badge>
    </template>
    <template slot="footer">
      <b-card-footer @mouseenter="$v.form.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="ctrlKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Syslog Entry?')" @on-delete="remove()"/>
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
  pfConfigurationSyslogForwarderViewFields as fields
} from '@/globals/configuration/pfConfigurationSyslogForwarders'
const { validationMixin } = require('vuelidate')

export default {
  name: 'SyslogForwarderView',
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
    syslogForwarderType: { // from router (or form)
      type: String,
      default: null
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
      return this.$v.$invalid || this.$store.getters[`${this.storeName}/isWaiting`]
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
      if (this.id) {
        // existing
        this.$store.dispatch(`${this.storeName}/optionsById`, this.id).then(options => {
          this.options = options
          this.$store.dispatch(`${this.storeName}/getSyslogForwarder`, this.id).then(form => {
            this.form = form
            this.syslogForwarderType = form.type
          })
        })
      } else {
        // new
        this.$store.dispatch(`${this.storeName}/optionsBySyslogForwarderType`, this.syslogForwarderType).then(options => {
          this.options = options
          this.form = defaults(options.meta) // set defaults
          this.form.type = this.syslogForwarderType
        })
      }
    },
    close (event) {
      this.$router.push({ name: 'syslogForwarders' })
    },
    clone () {
      this.$router.push({ name: 'cloneSyslogForwarder' })
    },
    create (event) {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/createSyslogForwarder`, this.form).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'syslogForwarder', params: { id: this.form.id } })
        }
      })
    },
    save (event) {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/updateSyslogForwarder`, this.form).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove (event) {
      this.$store.dispatch(`${this.storeName}/deleteSyslogForwarder`, this.id).then(response => {
        this.close()
      })
    },
    setValidations (validations) {
      this.$set(this, 'formValidations', validations)
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
