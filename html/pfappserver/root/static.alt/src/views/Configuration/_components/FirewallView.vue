<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :isLoading="isLoading"
    :disabled="isLoading"
    :isDeletable="isDeletable"
    :isNew="isNew"
    :isClone="isClone"
    :view="view"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template v-slot:header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="d-inline mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Firewall SSO {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Firewall SSO {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Firewall SSO') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="firewallType"></b-badge>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="isDisabled" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="actionKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Firewall?')" @on-delete="remove()"/>
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
} from '../_config/firewall'

export default {
  name: 'firewall-view',
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
    firewallType: { // from router (or form)
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
      return view(this.form, this.meta) // ../_config/firewall
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_firewalls/isLoading']
    },
    isDisabled () {
      return this.invalidForm || this.isLoading
    },
    isDeletable () {
      const { isNew, isClone, form: { not_deletable: notDeletable = false } = {} } = this
      if (isNew || isClone || notDeletable) {
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
      if (this.id) { // existing
        this.$store.dispatch('$_firewalls/optionsById', this.id).then(options => {
          const { meta = {} } = options
          this.$store.dispatch('$_firewalls/getFirewall', this.id).then(form => {
            const firewallType = form.type
            if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
            const { isNew, isClone} = this
            this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, firewallType } })
          })
        })
      } else { // new
        this.$store.dispatch('$_firewalls/optionsByFirewallType', this.firewallType).then(options => {
          const { meta = {} } = options
          this.$store.dispatch(`${this.formStoreName}/setForm`, defaults(meta)) // set defaults
          this.form.type = this.firewallType
          const { isNew, isClone, firewallType } = this
          this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, firewallType } })
        })
      }
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'firewalls' })
    },
    clone () {
      this.$router.push({ name: 'cloneFirewall' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_firewalls/createFirewall', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'firewall', params: { id: this.form.id } })
        }
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_firewalls/updateFirewall', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch('$_firewalls/deleteFirewall', this.id).then(() => {
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
