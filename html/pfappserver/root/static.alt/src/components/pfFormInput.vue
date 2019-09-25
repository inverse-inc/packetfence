<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="isValid()"
    class="pf-form-input" :class="{ 'mb-0': !columnLabel }">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!getInvalidFeedback()"></icon> {{ feedbackState }}
    </template>
    <b-input-group>
      <b-form-input
        v-model="inputValue"
        v-bind="$attrs"
        ref="input"
        :state="isValid()"
        :disabled="disabled"
        :readonly="readonly"
        @input.native="validate()"
        @keyup.native="onChange($event)"
        @change.native="onChange($event)"
      />
      <b-input-group-append v-if="readonly || disabled || test">
        <b-button v-if="readonly || disabled" class="input-group-text" tabindex="-1" disabled><icon name="lock"></icon></b-button>
        <b-button-group v-else-if="test" rel="testResultGroup">
          <b-button v-if="testResult !== null" variant="light" disabled tabindex="-1">
            <span class="mr-1" :class="{ 'text-danger': !testResult, 'text-success': testResult }">{{ testMessage }}</span>
          </b-button>
        </b-button-group>
        <b-button-group v-if="!disabled" rel="prefixButtonGroup">
          <b-button v-if="test" class="input-group-text" @click="runTest()" :disabled="isLoading || isTesting || !this.value || isValid() === false" tabindex="-1">
            {{ $t('Test') }}
            <icon v-show="isTesting" name="circle-notch" spin class="ml-2 mr-1"></icon>
            <icon v-if="testResult !== null && testResult" name="check" class="ml-2 mr-1 text-success"></icon>
            <icon v-if="testResult !== null && !testResult" name="times" class="ml-2 mr-1 text-danger"></icon>
          </b-button>
        </b-button-group>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-input',
  mixins: [
    pfMixinValidation
  ],
  props: {
    value: {
      default: null
    },
    columnLabel: {
      type: String
    },
    labelCols: {
      type: Number,
      default: 3
    },
    text: {
      type: String,
      default: null
    },
    disabled: {
      type: Boolean,
      default: false
    },
    readonly: {
      type: Boolean,
      default: false
    },
    formatter: {
      type: Function,
      default: null
    },
    test: {
      type: Function,
      default: null
    }
  },
  data () {
    return {
      testResult: null,
      testMessage: null,
      isTesting: false
    }
  },
  computed: {
    inputValue: {
      get () {
        return (this.formatter) ? this.formatter(this.value) : this.value
      },
      set (newValue) {
        this.$emit('input', newValue || null)
      }
    }
  },
  methods: {
    focus () {
      this.$refs.input.focus()
    },
    runTest () {
      if (this.test) {
        this.isTesting = true
        this.testResult = null
        this.test().then(response => {
          this.testResult = true
          this.testMessage = null
          this.$emit('pass')
          this.isTesting = false
        }).catch(err => {
          this.testResult = false
          this.testMessage = this.$i18n.t('Test failed with unknown error.')
          const { response: { data = null } = {} } = err
          if (data) {
            const { message = null } = data
            if (message) this.testMessage = message
            this.$emit('fail', data)
          }
          this.isTesting = false
        })
      }
    }
  }
}
</script>

<style lang="scss" scoped>
/**
 * Add btn-primary color(s) on hover
 */
.btn-group[rel=testResultGroup] button {
  opacity: 1;
  text-transform: none;
}
.btn-group[rel=prefixButtonGroup] button:not(.disabled):hover {
  background-color: $input-btn-hover-bg-color;
  color: $input-btn-hover-text-color;
  border-color: $input-btn-hover-bg-color;
  cursor: pointer;
}
</style>
