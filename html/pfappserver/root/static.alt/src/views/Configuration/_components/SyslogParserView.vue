<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :is-loading="isLoading"
    :disabled="isLoading"
    :is-deletable="isDeletable"
    :is-new="isNew"
    :is-clone="isClone"
    :view="view"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template v-slot:header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="d-inline mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Syslog Parser {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Syslog Parser {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Syslog Parser') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="syslogParserType"></b-badge>
    </template>
    <template v-slot:footer>
      <b-card-footer>
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
  defaultsFromMeta as defaults
} from '../_config/'
import {
  view,
  validators
} from '../_config/syslogParser'

export default {
  name: 'syslog-parser-view',
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete
  },
  props: {
    formStoreName: { // from router
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
      dryRunResponseHtml: '' // will be overloaded with data from dryRun
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
      return view(this.form, this.meta) // ../_config/syslogParser
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_syslog_parsers/isLoading']
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
        this.$store.dispatch('$_syslog_parsers/optionsById', this.id).then(options => {
          const { meta = {} } = options
          this.$store.dispatch('$_syslog_parsers/getSyslogParser', this.id).then(form => {
            if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
            const { isNew, isClone, isDeletable, dryRunTest, dryRunResponseHtml } = this
            const syslogParserType = form.type
            this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, isDeletable, dryRunTest, dryRunResponseHtml, syslogParserType } })
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
          })
        })
      } else {
        // new
        const { isNew, isClone, isDeletable, dryRunTest, dryRunResponseHtml, syslogParserType } = this
        this.$store.dispatch('$_syslog_parsers/optionsBySyslogParserType', syslogParserType).then(options => {
          const { meta = {} } = options
          this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, isDeletable, dryRunTest, dryRunResponseHtml, syslogParserType } })
          this.$store.dispatch(`${this.formStoreName}/setForm`, { ...defaults(meta), type: syslogParserType }) // set defaults
        })
      }
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'syslogParsers' })
    },
    clone () {
      this.$router.push({ name: 'cloneSyslogParser' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_syslog_parsers/createSyslogParser', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'syslogParser', params: { id: this.form.id } })
        }
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_syslog_parsers/updateSyslogParser', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch('$_syslog_parsers/deleteSyslogParser', this.id).then(() => {
        this.close()
      })
    },
    dryRunTest () {
      this.dryRunResponseHtml = null
      let form = JSON.parse(JSON.stringify(this.form)) // dereference
      if ('lines' in form) {
        form.lines = form.lines.split('\n') // split lines by \n
      }
      this.$store.dispatch('$_syslog_parsers/dryRunSyslogParser', form).then(response => {
        let html = []
        html.push(`<h5>${this.$i18n.t('Results')}</h5>`)
        html.push('<pre>')
        response.items.forEach((item, index) => {
          html.push(`<code>${this.$i18n.t('Line')} ${index + 1}\t- <strong>${item.line}</strong></code><br/>`)
          if (item.matches.length > 0) {
            item.matches.forEach((match) => {
              match.actions.forEach((action) => {
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
      handler: function () {
        this.init()
      }
    },
    isClone: {
      handler: function () {
        this.init()
      }
    },
    escapeKey (pressed) {
      if (pressed) this.close()
    }
  }
}
</script>
