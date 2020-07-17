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
      <h4 class="mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Domain {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Domain {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Domain') }}</span>
      </h4>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="isDisabled" :isLoading="isLoading">
          <template v-if="isNew && !actionKey">{{ $t('Create & Join') }}</template>
          <template v-else-if="isNew && actionKey">{{ $t('Create') }}</template>
          <template v-else-if="isClone && !actionKey">{{ $t('Clone & Join') }}</template>
          <template v-else-if="isClone && actionKey">{{ $t('Clone') }}</template>
          <template v-else-if="!isNew && !isClone && !actionKey">{{ $t('Save') }}</template>
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
import {
  defaultsFromMeta as defaults
} from '../_config/'
import {
  view,
  validators
} from '../_config/domain'

export default {
  name: 'domain-view',
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
      return view(this.form, this.meta) // ../_config/domain
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_domains/isLoading']
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
      this.$store.dispatch('$_domains/options', this.id).then(options => {
        const { meta = {} } = options
        const { isNew, isClone } = this
        this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone } })
        if (this.id) { // existing
          this.$store.dispatch('$_domains/getDomain', this.id).then(form => {
            if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
          })
        } else { // new
          this.$store.dispatch(`${this.formStoreName}/setForm`, defaults(options.meta)) // set defaults
        }
      })
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'domains' })
    },
    clone () {
      this.$router.push({ name: 'cloneDomain' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_domains/createDomain', this.form).then(() => {
        if (!actionKey) {
          this.$router.push({ name: 'domains', params: { autoJoinDomain: this.form } })
        } else {
          this.$router.push({ name: 'domain', params: { id: this.form.id } })
        }
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_domains/updateDomain', this.form).then(() => {
        if ((this.isNew && !actionKey) || (this.isClone && !actionKey) || (!this.isNew && !this.isClone && actionKey)) {
          this.$router.push({ name: 'domains', params: { autoJoinDomain: this.form } })
        }
      })
    },
    remove () {
      this.$store.dispatch('$_domains/deleteDomain', this.id).then(() => {
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
