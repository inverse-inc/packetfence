<template>
  <span>
    <b-button :disabled="isDisabled" v-bind="$attrs" @click="open()">
      <icon class="mr-1" name="download"></icon> {{ $t('Download Certificate') }}
    </b-button>
    <b-modal v-model="showModal" size="lg" @hidden="close()"
      centered
      :hide-header-close="isLoading"
      :no-close-on-backdrop="isLoading"
      :no-close-on-esc="isLoading"
    >
      <template v-slot:modal-title>
        <h4>{{ $t('Download PKCS-12 Certificate') }}</h4>
        <b-form-text v-t="'Choose a password to encrypt the certificate.'" class="mb-0"></b-form-text>
      </template>
      <b-form-group class="mb-0">
        <pf-form-password :column-label="$t('Password')" :disabled="isLoading"
          v-model="password"
          :state="state" :invalid-feedback="invalidFeedback"
          :text="$t('The certificate will be encrypted with this password.')"
          generate
        />
        <pf-form-range-toggle :column-label="$t('Copy to clipboard')" :disabled="isLoading"
          v-model="clipboard"
          :text="$t('Copy the password to the clipboard.')"
          :values="{ checked: true, unchecked: false }"
        />
      </b-form-group>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="close()">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" @click="start()" :disabled="isLoading || invalidForm">
          <icon v-if="isLoading" class="mr-1" name="circle-notch" spin></icon> {{ $t('Download P12') }}
        </b-button>
      </template>
    </b-modal>
  </span>
</template>

<script>
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  required,
  minLength
} from 'vuelidate/lib/validators'

const { validationMixin } = require('vuelidate')

export default {
  name: 'pf-button-pki-cert-download',
  components: {
    pfFormPassword,
    pfFormRangeToggle
  },
  mixins: [
    validationMixin
  ],
  data () {
    return {
      isLoading: false,
      showModal: false,
      password: null,
      clipboard: false
    }
  },
  props: {
    cert: {
      type: Object,
      default: () => { return {} }
    },
    download: {
      type: Function,
      default: () => {}
    },
    disabled: {
      type: Boolean,
      default: false
    }
  },
  computed: {
    isDisabled () {
     return this.disabled || this.isLoading
    },
    invalidForm () {
      return this.$v.password.$invalid
    },
    state () {
      return !this.invalidForm
    },
    invalidFeedback () {
      const invalidFeedback = []
      const { password, password: { $params } = {} } = this.$v
      for (const key of Object.keys($params)) {
        if (key in password && password[key] === false) {
          invalidFeedback.push(key)
        }
      }
      return invalidFeedback.join('. ')
    }
  },
  methods: {
    open () {
      this.showModal = true
    },
    close () {
      this.showModal = false
    },
    start () {
      const { cert: { ID: id, ca_name, profile_name, cn } = {}, password = null } = this
      const filename = `${ca_name}-${profile_name}-${cn}.p12`
      this.isLoading = true
      Promise.resolve(this.download(id, password, filename)).then(() => {
        if (this.clipboard) { // copy password to clipboard
          try {
            navigator.clipboard.writeText(password).then(() => {
              this.$store.dispatch('notification/info', { message: this.$i18n.t('Certificate password copied to clipboard') })
            })
          } catch (e) {
            // noop
          }
        }
      }).finally(() => {
        this.isLoading = false
        this.close()
      })
    }
  },
  validations () {
    return {
      password: {
        [this.$i18n.t('Password required.')]: required,
        [this.$i18n.t('Minimum 8 characters.')]: minLength(8)
      }
    }
  }
}
</script>
