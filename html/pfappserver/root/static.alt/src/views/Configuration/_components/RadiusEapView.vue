<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :isLoading="isLoading"
    :disabled="isLoading"
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
        <span v-if="!isNew && !isClone" v-html="$t('EAP Profile')"></span>
        <span v-else-if="isClone" v-html="$t('Clone EAP Profile')"></span>
        <span v-else>{{ $t('New EAP Profile') }}</span>
      </h4>
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
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete EAP Profile?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonSave from '@/components/pfButtonSave'
import pfConfigView from '@/components/pfConfigView'
import {
  defaultsFromMeta as defaults
} from '../_config/'
import {
  view,
  validators
} from '../_config/radius/eap'

export default {
  name: 'radius-eap-view',
  components: {
    pfButtonDelete,
    pfButtonSave,
    pfConfigView
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
      return view(this.form, this.meta) // ../_config/pki/ca
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_radius_eap/isLoading']
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
      const { isNew, isClone } = this
      this.$store.dispatch(`${this.formStoreName}/clearForm`)
      this.$store.dispatch(`${this.formStoreName}/clearMeta`)
      if (this.id) {
        // existing
        this.$store.dispatch('$_radius_eap/options', this.id).then(options => {
          const { meta = {} } = options
          this.$store.dispatch('$_radius_eap/getRadiusEap', this.id).then(form => {
            if (isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
            this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone } })
          })
        })
      } else {
        // new
        this.$store.dispatch('$_radius_eap/options').then(options => {
          const { meta = {} } = options
          this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone } })
          this.$store.dispatch(`${this.formStoreName}/setForm`, defaults(meta))
        })
      }
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'radiusEaps' })
    },
    clone () {
      this.$router.push({ name: 'cloneRadiusEap' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_radius_eap/createRadiusEap', this.form).then(item => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          const { id } = item
          this.$router.push({ name: 'radiusEap', params: { id } })
        }
      }).catch(e => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Could not create EAP configuration: ') + e })
      })
    },
    remove () {
      this.$store.dispatch('$_radius_eap/deleteRadiusEap', this.id).then(() => {
        this.close()
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_radius_eap/updateRadiusEap', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
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
