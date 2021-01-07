<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="inputState"
    class="pf-form-input" :class="{ 'mb-0': !columnLabel }">
    <template v-slot:invalid-feedback>
      {{ inputInvalidFeedback }}
    </template>
    <b-input-group>
      <b-form-input ref="input"
        v-model="inputValue"
        v-bind="$attrs"
        :state="inputState"
        :disabled="disabled"
        :readonly="readonly"
      />
      <b-input-group-append v-show="$slots.append || readonly || disabled || test">
        <b-button-group v-show="$slots.append" rel="testResultGroup">
          <slot name="append"></slot>
        </b-button-group>
        <b-button-group v-show="test" rel="testResultGroup">
          <b-button v-show="testResult !== null" variant="light" disabled tabindex="-1">
            <span class="mr-1" :class="{ 'text-danger': !testResult, 'text-success': testResult }">{{ testMessage }}</span>
          </b-button>
        </b-button-group>
        <b-button-group v-show="test" rel="prefixButtonGroup">
          <b-button class="input-group-text" @click="runTest()" :disabled="readonly || disabled || isTesting || !inputValue || inputState === false" tabindex="-1">
            {{ $t('Test') }}
            <icon v-show="isTesting" name="circle-notch" spin class="ml-3 mr-1"></icon>
            <icon v-show="testResult !== null && testResult" name="check" class="ml-3 mr-1 text-success"></icon>
            <icon v-show="testResult !== null && !testResult" name="times" class="ml-3 mr-1 text-danger"></icon>
          </b-button>
        </b-button-group>
        <b-button v-show="!isTesting && (readonly || disabled)" class="input-group-text" tabindex="-1" disabled><icon name="lock"></icon></b-button>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-show="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinForm from '@/components/pfMixinForm'

export default {
  name: 'pf-form-input',
  mixins: [
    pfMixinForm
  ],
  props: {
    value: {
      default: null
    },
    columnLabel: {
      type: String
    },
    labelCols: {
      type: [String, Number],
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
        if (this.formStoreName) {
          return this.formStoreValue // use FormStore
        } else {
          return this.value // use native (v-model)
        }
      },
      set (newValue = null) {
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.$emit('input', newValue) // use native (v-model)
        }
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
        this.test().then(() => {
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
