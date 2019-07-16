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
        <span v-if="!isNew && !isClone" v-html="$t('Syslog Parser {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Syslog Parser {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Syslog Parser') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="syslogParserType"></b-badge>
    </template>
    <template slot="footer">
      <b-card-footer @mouseenter="$v.form.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="actionKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Syslog Parser?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import {
  pfConfigurationDefaultsFromMeta as defaults
} from '@/globals/configuration/pfConfiguration'
import {
  pfConfigurationSyslogParserViewFields as fields
} from '@/globals/configuration/pfConfigurationSyslogParsers'
const { validationMixin } = require('vuelidate')

export default {
  name: 'syslog-parser-view',
  mixins: [
    validationMixin
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
    syslogParserType: { // from router (or form)
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
      formValidations: {}, // will be overloaded with data from the pfConfigView,
      dryRunResponseHtml: '', // will be overloaded with data from dryRun
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
    },
    keyLabelMap () {
      let keyLabelMap = {}
      this.getForm.fields.forEach(tab => {
        tab.fields.forEach(row => {
          if ('fields' in row) {
            row.fields.forEach(col => {
              if ('key' in col) keyLabelMap[col.key] = row.label
            })
          }
        })
      })
      return keyLabelMap
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    }
  },
  methods: {
    init () {
      if (this.id) {
        // existing
        this.$store.dispatch(`${this.storeName}/optionsById`, this.id).then(options => {
          this.options = options
          this.$store.dispatch(`${this.storeName}/getSyslogParser`, this.id).then(form => {
            if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
            this.form = form
            this.syslogParserType = form.type
          })
        })
      } else {
        // new
        this.$store.dispatch(`${this.storeName}/optionsBySyslogParserType`, this.syslogParserType).then(options => {
          this.options = options
          this.form = defaults(options.meta) // set defaults
          this.form.type = this.syslogParserType
        })
      }
    },
    close (event) {
      this.$router.push({ name: 'syslogParsers' })
    },
    clone () {
      this.$router.push({ name: 'cloneSyslogParser' })
    },
    create (event) {
      const actionKey = this.actionKey
      this.$store.dispatch(`${this.storeName}/createSyslogParser`, this.form).then(response => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'syslogParser', params: { id: this.form.id } })
        }
      })
    },
    save (event) {
      const actionKey = this.actionKey
      this.$store.dispatch(`${this.storeName}/updateSyslogParser`, this.form).then(response => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove (event) {
      this.$store.dispatch(`${this.storeName}/deleteSyslogParser`, this.id).then(response => {
        this.close()
      })
    },
    setValidations (validations) {
      this.$set(this, 'formValidations', validations)
    },
    dryRunTest (event) {
      this.dryRunResponseHtml = null
      let form = JSON.parse(JSON.stringify(this.form)) // dereference
      if ('lines' in form) {
        form.lines = form.lines.split('\n') // split lines by \n
      }
      this.$store.dispatch(`${this.storeName}/dryRunSyslogParser`, form).then(response => {
        let html = []
        html.push(`<h5>${this.$i18n.t('Results')}</h5>`)
        html.push('<pre>')
        response.items.forEach((item, lIndex) => {
          html.push(`<code>${this.$i18n.t('Line')} ${lIndex + 1}\t- <strong>${item.line}</strong></code><br/>`)
          if (item.matches.length > 0) {
            item.matches.forEach((match, mIndex) => {
              match.actions.forEach((action, aIndex) => {
                html.push(`\t- ${match.rule.name}: ${action.api_method}(${action.api_parameters.map(param => '\'' + param + '\'').join(', ')})<br/>`)
              })
            })
          } else {
            html.push(`\t- ${this.$i18n.t('No Rules Matched')}<br/>`)
          }
        })
        html.push('</pre>')
        this.dryRunResponseHtml = html.join('')
      }).catch(err => {
        let html = []
        const { response: { data: { errors = [] } } } = err
        errors.forEach((error) => {
          if (error.field in this.keyLabelMap) {
            error.field = this.$i18n.t(this.keyLabelMap[error.field])
          }
          html.push(this.$i18n.t('Server Error - "{field}": {message}', error) + '<br/>')
        })
        this.dryRunResponseHtml = html.join('')
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
    },
    escapeKey (pressed) {
      if (pressed) this.close()
    }
  }
}
</script>
