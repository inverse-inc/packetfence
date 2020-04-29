<template>
  <b-card no-body>
    <b-card-header>
      <h4 v-t="'Live Logs'"></h4>
    </b-card-header>

    <live-log-tabs />

    <b-card-body>
      <b-form @submit.prevent="create()">
        <b-form-row align-v="center">
          <b-col sm="12">
            <pf-form-input :column-label="$t('Name')"
              v-model="form.name"
              :state="state('name')"
              :invalid-feedback="invalidFeedback('name')"
            />
            <pf-form-chosen :column-label="$t('Log Files')"
              v-model="form.files"
              :placeholder="$t('Choose file(s)')"
              :options="files"
              :multiple="true"
              :state="state('files')"
              :invalid-feedback="invalidFeedback('files')"
              label="name" track-by="value"
            />
            <pf-form-input :column-label="$t('Filter')"
              v-model="form.filter"
            />
            <pf-form-range-toggle :column-label="$t('Regular Expression')"
              v-model="form.filter_is_regexp"
              :values="{checked: true, unchecked: false}"
              :rightLabels="{checked: $t('Yes'), unchecked: $t('No')}"
            />
          </b-col>
        </b-form-row>
      </b-form>
    </b-card-body>
    <b-card-footer>
      <b-button variant="primary" :disabled="invalidForm" @click="create()">
        <icon name="circle-notch" spin v-show="isLoading"></icon> {{ $t('Start Session') }}
      </b-button>
    </b-card-footer>
  </b-card>
</template>

<script>
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import liveLogTabs from './LiveLogTabs'

import { validationMixin } from 'vuelidate'
import {
  required
} from 'vuelidate/lib/validators'
import {
  and,
  not,
  conditional
} from '@/globals/pfValidators'

export default {
  name: 'live-log-create',
  components: {
    liveLogTabs,
    pfFormChosen,
    pfFormInput,
    pfFormRangeToggle
  },
  mixins: [
    validationMixin
  ],
  props: {
    storeName: {
      type: String,
      default: null
    }
  },
  data () {
    return {
      form: {
        name: this.$i18n.t('New Session'),
        files: [],
        filter: null,
        filter_is_regexp: false
      },
      files: [
        '/usr/local/pf/logs/packetfence.log',
        '/usr/local/pf/logs/http.portal.access'
      ].map(file => {
        let split = file.split('/')
        return { name: split[split.length - 1], value: file }
      })
    }
  },
  methods: {
    create () {
      this.$store.dispatch(`${this.storeName}/createSession`, this.form).then(response => {
        // noop
      })
    }
  },
  computed: {
    invalidForm () {
      const { $v: { $invalid = false } = {} } = this
      return $invalid
    },
    invalidFeedback () {
      return (key) => {
        const { $v: { form: { [key]: { $params } = {} } = {} } = {} } = this
        let feedback = []
        for (let param in $params) {
          const { $v: { form: { [key]: { [param]: valid = true } = {} } = {} } = {} } = this
          if (!valid) {
            feedback.push(param)
          }
        }
        return feedback.join(' ')
      }
    },
    state () {
      return (key) => {
        const { $v: { form: { [key]: { $invalid = false } = {} } = {} } = {} } = this
        return ($invalid) ? false : null
      }
    },
    sessions () {
      return this.$store.getters['$_live_logs/sessions']
    }
  },
  validations () {
    const hasSessions = () => {
      return this.sessions.length > 0
    }
    const sessionExists = (value) => {
      let sessionIndex = this.sessions.findIndex(session => {
        return session.name === value
      })
      return sessionIndex > -1
    }
    return {
      form: {
        name: {
          [this.$i18n.t('Session name required.')]: required,
          [this.$i18n.t('Session exists.')]: not(and(required, hasSessions, sessionExists))
        },
        files: {
          [this.$i18n.t('Log file(s) required.')]: required
        }
      }
    }
  }
}
</script>
