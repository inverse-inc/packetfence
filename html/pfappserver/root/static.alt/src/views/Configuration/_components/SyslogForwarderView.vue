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
        <span v-if="!isNew && !isClone" v-html="$t('Syslog Entry {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Syslog Entry {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Syslog Entry') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="syslogForwarderType"></b-badge>
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
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Syslog Entry?')" @on-delete="remove()"/>
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
} from '../_config/syslogForwarder'

export default {
  name: 'syslog-forwarder-view',
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
  computed: {
    meta () {
      return this.$store.getters[`${this.formStoreName}/$meta`]
    },
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    view () {
      return view(this.form, this.meta) // ../_config/syslogForwarder
    },
    isLoading () {
      return this.$store.getters['$_syslog_forwarders/isLoading']
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isDeletable () {
      if (this.isNew || this.isClone || ('not_deletable' in this.form && this.form.not_deletable)) {
        return false
      }
      return true
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
        this.$store.dispatch('$_syslog_forwarders/optionsById', this.id).then(options => {
          const { meta = {} } = options
          this.$store.dispatch('$_syslog_forwarders/getSyslogForwarder', this.id).then(form => {
            if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
            const { isNew, isClone, isDeletable } = this
            const syslogForwarderType = form.type
            this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, isDeletable, syslogForwarderType } })
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
          })
        })
      } else {
        // new
        const { isNew, isClone, isDeletable, syslogForwarderType } = this
        this.$store.dispatch('$_syslog_forwarders/optionsBySyslogForwarderType', syslogForwarderType).then(options => {
          const { meta = {} } = options
          this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, isDeletable, syslogForwarderType } })
          this.$store.dispatch(`${this.formStoreName}/setForm`, { ...defaults(meta), type: syslogForwarderType }) // set defaults
        })
      }
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'syslogForwarders' })
    },
    clone () {
      this.$router.push({ name: 'cloneSyslogForwarder' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_syslog_forwarders/createSyslogForwarder', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'syslogForwarder', params: { id: this.form.id } })
        }
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_syslog_forwarders/updateSyslogForwarder', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch('$_syslog_forwarders/deleteSyslogForwarder', this.id).then(() => {
        this.close()
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
