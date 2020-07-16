<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :is-loading="isLoading"
    :disabled="isLoading"
    :is-deletable="isDeletable"
    :is-new="isNew"
    :view="view"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template v-slot:header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="!isNew" v-html="$t('Traffic Shaping Policy {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Traffic Shaping Policy') }}</span>
      </h4>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="actionKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Traffic Shaping Policy?')" @on-delete="remove()"/>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
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
} from '../_config/trafficShapingPolicy'

export default {
  name: 'traffic-shaping-view',
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
    id: { // from router
      type: String,
      default: null
    },
    role: { // from router
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
      return view(this.form, this.meta) // ../_config/trafficShapingPolicy
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_traffic_shaping_policies/isLoading']
    },
    isDeletable () {
      if (this.isNew || ('not_deletable' in this.form && this.form.not_deletable)) {
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
      this.$store.dispatch('$_traffic_shaping_policies/options', this.id).then(options => {
        const { meta = {} } = options
        const { isNew, isDeletable } = this
        this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isDeletable } })
        this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
        if (this.id) {
          // existing
          this.$store.dispatch('$_traffic_shaping_policies/getTrafficShapingPolicy', this.id).then(form => {
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
          })
        } else {
          // new
          this.$store.dispatch(`${this.formStoreName}/setForm`, defaults(options.meta)) // set defaults
          this.$store.dispatch(`${this.formStoreName}/setForm`, { ...defaults(meta), ...{ id: this.role } }) // set defaults
        }
      })
    },
    close () {
      this.$router.push({ name: 'traffic_shapings' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_traffic_shaping_policies/createTrafficShapingPolicy', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'traffic_shaping', params: { id: this.form.id } })
        }
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_traffic_shaping_policies/updateTrafficShapingPolicy', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch('$_traffic_shaping_policies/deleteTrafficShapingPolicy', this.id).then(() => {
        this.close()
      })
    }
  },
  created () {
    this.init()
  },
  watch: {
    escapeKey (pressed) {
      if (pressed) this.close()
    }
  }
}
</script>
