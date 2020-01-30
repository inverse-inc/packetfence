<template>
  <span>
    <b-button :disabled="isDisabled" v-bind="$attrs" @click="open()">
      {{ $t('Revoke') }}
    </b-button>
    <b-modal v-model="showModal" size="lg" @shown="focus()" @hidden="close()"
      centered
      :hide-header-close="isLoading"
      :no-close-on-backdrop="isLoading"
      :no-close-on-esc="isLoading"
    >
      <template v-slot:modal-title>
        <h4>{{ $t('Revoke Certificate') }}</h4>
        <b-form-text v-t="'Choose a reason to revoke the certificate.'" class="mb-0"></b-form-text>
      </template>
      <b-form-group class="mb-0">
        <pf-form-chosen ref="reason" :column-label="$t('Reason')" :disabled="isLoading"
          v-model="reason"
          :state="state" :invalid-feedback="invalidFeedback"
          :text="$t('The certificate will be revoked for this reason.')"
          :options="revokeReasons"
        />
      </b-form-group>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="close()">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" @click="start()" :disabled="isLoading || invalidForm">
          <icon v-if="isLoading" class="mr-1" name="circle-notch" spin></icon> {{ $t('Revoke') }}
        </b-button>
      </template>
    </b-modal>
  </span>
</template>

<script>
import pfFormChosen from '@/components/pfFormChosen'
import {
  revokeReasons
} from '@/views/Configuration/_config/pki/'
import {
  required
} from 'vuelidate/lib/validators'

const { validationMixin } = require('vuelidate')

export default {
  name: 'pf-button-pki-cert-revoke',
  components: {
    pfFormChosen
},
  mixins: [
    validationMixin
  ],
  data () {
    return {
      revokeReasons, // @/views/Configuration/_config/pki/
      isLoading: false,
      showModal: false,
      reason: null
    }
  },
  props: {
    cert: {
      type: Object,
      default: () => { return {} }
    },
    revoke: {
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
      return this.$v.reason.$invalid
    },
    state () {
      return !this.invalidForm
    },
    invalidFeedback () {
      const invalidFeedback = []
      const { reason, reason: { $params } = {} } = this.$v
      for (const key of Object.keys($params)) {
        if (key in reason && reason[key] === false) {
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
    focus () {
      this.$refs.reason.focus()
    },
    start () {
      const { cert: { ID: id, cn } = {}, reason = null } = this
      this.isLoading = true
      Promise.resolve(this.revoke(id, reason)).then(() => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Certificate <code>{cn}</code> revoked.', { cn }) })
      }).catch(e => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Could not revoke certificate <code>{cn}</code>.<br/>Reason: ', { cn }) + e })
      }).finally(() => {
        this.isLoading = false
        this.close()
        this.$emit('on-delete', true)
      })
    }
  },
  validations () {
    return {
      reason: {
        [this.$i18n.t('Reason required.')]: required
      }
    }
  }
}
</script>
