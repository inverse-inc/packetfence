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
  >
    <template v-slot:header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="d-inline mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Certificate')"></span>
        <span v-else-if="isClone" v-html="$t('Clone Certificate')"></span>
        <span v-else>{{ $t('New Certificate') }}</span>
      </h4>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save v-if="isNew || isClone" :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
        </pf-button-save>
        <b-button v-if="isNew || isClone" :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-pki-cert-download v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary"
          :cert="form" :download="download"
        />
        <b-button v-if="!isNew && !isClone && form.mail" :disabled="isLoading" variant="outline-primary" class="ml-1" @click="email()">
          <icon class="mr-1" name="at"></icon> {{ $t('Email') }}
        </b-button>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfButtonPkiCertDownload from '@/components/pfButtonPkiCertDownload'
import pfButtonSave from '@/components/pfButtonSave'
import pfConfigView from '@/components/pfConfigView'
import {
  view,
  validators,
  download
} from '../_config/pki/cert'

export default {
  name: 'pki-cert-view',
  components: {
    pfButtonPkiCertDownload,
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
    },
    profile_id: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      download, // ../_config/pki/cert
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
      return view(this.form, this.meta) // ../_config/pki/cert
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_pkis/isLoading']
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    },
    profiles: { // mutating this property will re-evaluate view() and validators()
      get () {
        const { meta: { profiles = [] } = {} } = this
        return profiles
      },
      set (newValue) {
        this.$set(this.meta, 'profiles', newValue)
      }
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_pkis/allProfiles').then(profiles => {
        this.profiles = profiles.sort((a, b) => { // sort profiles
          return (a.ca_name === b.ca_name)
            ? a.name.localeCompare(b.name)
            : a.ca_name.localeCompare(b.ca_name)
        })
      })
      const { isNew, isClone, profiles, profile_id } = this
      this.$store.dispatch(`${this.formStoreName}/setMeta`, { isNew, isClone, profiles })
      this.$store.dispatch(`${this.formStoreName}/clearForm`)
      if (this.id) {
        // existing
        this.$store.dispatch('$_pkis/getCert', this.id).then(form => {
          if (profile_id) {
            this.$store.dispatch(`${this.formStoreName}/setForm`, { ...form, ...{ profile_id } })
          } else {
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
          }
        })
      } else {
        this.$store.dispatch(`${this.formStoreName}/setForm`, { profile_id })
      }
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'pkiCerts' })
    },
    clone () {
      this.$router.push({ name: 'clonePkiCert' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_pkis/createCert', this.form).then(item => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          const { ID: id } = item
          this.$router.push({ name: 'pkiCert', params: { id } })
        }
      }).catch(e => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Could not create Certificate.<br/>Reason: ') + e })
      })
    },
    email () {
      const { cn, mail } = this.form
      if (mail) {
        this.$store.dispatch('$_pkis/emailCert', cn).then(response => {
          this.$store.dispatch('notification/success', { message: this.$i18n.t('Certificate <code>{cn}</code> emailed to <code>{mail}</code>', { cn, mail }) })
        }).catch(e => {
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Could not email certificate <code>{cn}</code> to <code>{mail}</code>.<br/>Reason: ', { cn, mail }) + e })
        })
      }
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
