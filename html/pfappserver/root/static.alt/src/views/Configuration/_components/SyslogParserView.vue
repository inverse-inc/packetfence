<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="syslogParser"
    :vuelidate="$v.syslogParser"
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
        <span v-if="!isNew && !isClone">{{ $t('Syslog Parser {id}', { id: id }) }}</span>
        <span v-else-if="isClone">{{ $t('Clone Syslog Parser {id}', { id: id }) }}</span>
        <span v-else>{{ $t('New Syslog Parser') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="syslogParserType"></b-badge>
    </template>
    <template slot="footer"
      scope="{isDeletable}"
    >
      <b-card-footer @mouseenter="$v.syslogParser.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="ctrlKey">{{ $t('Save &amp; Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Syslog Parser?')" @on-delete="remove()"/>
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
  pfConfigurationSyslogParserViewFields as fields,
  pfConfigurationSyslogParserViewDefaults as defaults
} from '@/globals/configuration/pfConfigurationSyslogParsers'
const { validationMixin } = require('vuelidate')

export default {
  name: 'SyslogParserView',
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
    syslogParserType: { // from router (or syslogParser)
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
      syslogParser: defaults(this), // will be overloaded with the data from the store
      syslogParserValidations: {}, // will be overloaded with data from the pfConfigView,
      dryRunResponseHtml: '' // will be overloaded with data from dryRun
    }
  },
  validations () {
    return {
      syslogParser: this.syslogParserValidations
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
      if (this.isNew || this.isClone || ('not_deletable' in this.syslogParser && this.syslogParser.not_deletable)) {
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
    }
  },
  methods: {
    close (event) {
      this.$router.push({ name: 'syslogParsers' })
    },
    create (event) {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/createSyslogParser`, this.syslogParser).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'syslogParser', params: { id: this.syslogParser.id } })
        }
      })
    },
    save (event) {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/updateSyslogParser`, this.syslogParser).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
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
      this.$set(this, 'syslogParserValidations', validations)
    },
    dryRunTest (event) {
      this.dryRunResponseHtml = null
      let form = JSON.parse(JSON.stringify(this.syslogParser)) // dereference
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
    if (this.id) {
      this.$store.dispatch(`${this.storeName}/getSyslogParser`, this.id).then(data => {
        this.syslogParserType = data.type
        this.syslogParser = Object.assign({}, data)
        if (this.isClone) {
          this.syslogParser.id = null
        }
      })
    }
    this.syslogParser.type = this.syslogParserType
  }
}
</script>
