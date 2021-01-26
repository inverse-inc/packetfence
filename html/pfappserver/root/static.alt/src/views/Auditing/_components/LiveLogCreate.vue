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
            <pf-form-chosen :column-label="$t('Log Files')"
              v-model="form.files"
              :placeholder="$t('Choose log file(s)')"
              :options="files"
              :multiple="true"
              :state="state('files')"
              :invalid-feedback="invalidFeedback('files')"
              :close-on-select="false"
              label="text" track-by="value"
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
      <b-button variant="primary" :disabled="isLoading || invalidForm" @click="create()">
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
  data () {
    return {
      form: {
        name: this.$i18n.t('New Session'),
        files: [],
        filter: null,
        filter_is_regexp: false
      },
      files: []
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`$_live_logs/optionsSession`, this.form).then(response => {
        const { meta: { files: { item: { allowed = [] } = {} } = {} } = {} } = response
        if (allowed) {
          this.files = allowed.map(item => {
            const { text, value } = item
            return { name: `${value} - ${text}`, value }
          }).sort((a, b) => {
            return a.value.localeCompare(b.value)
          })
        }
      })
    },
    create () {
      this.$store.dispatch(`$_live_logs/createSession`, this.form).then(response => {
        const { session_id } = response
        if (session_id) {
          this.$router.push({ name: 'live_log', params: { id: session_id } })
        }
      })
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`$_live_logs/isLoading`]
    },
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
    return {
      form: {
        files: {
          [this.$i18n.t('Log file(s) required.')]: required
        }
      }
    }
  },
  mounted () {
    this.init()
  }
}
</script>
