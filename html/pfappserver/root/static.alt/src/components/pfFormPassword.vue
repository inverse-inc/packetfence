<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)" :state="inputState"
    class="pf-form-password" :class="{ 'mb-0': !columnLabel, 'is-focus': isFocus }">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!inputInvalidFeedback"></icon> {{ inputInvalidFeedback }}
    </template>
    <b-input-group class="pf-form-password-input-group">
      <b-form-input
        v-model="inputValue"
        v-bind="$attrs"
        ref="input"
        :type="type"
        :state="inputState"
        :disabled="disabled"
        @keyup.native="resetTest($event)"
        @focus.native="isFocus = true"
        @blur.native="isFocus = false"
      />
      <b-input-group-append>
        <b-button v-if="disabled" class="input-group-text" tabindex="-1" disabled><icon name="lock"></icon></b-button>
        <b-button v-else-if="generate"
          class="input-group-text" variant="light"
          :id="uuid"
          :aria-label="$t('Generate password')" :title="$t('Generate password')"
          ><icon name="random"></icon></b-button>
        <b-button-group v-else-if="test" rel="testResultGroup">
          <b-button v-if="testResult !== null" variant="light" disabled tabindex="-1">
            <span class="mr-1" :class="{ 'text-danger': !testResult, 'text-success': testResult }">{{ testMessage }}</span>
          </b-button>
        </b-button-group>
        <b-button-group v-if="!disabled" rel="prefixButtonGroup">
          <b-button v-if="test" class="input-group-text" @click="runTest()" :disabled="!allowTest" tabindex="-1">
            {{ $t('Test') }}
            <icon v-show="isTesting" name="circle-notch" spin class="ml-2 mr-1"></icon>
            <icon v-if="testResult !== null && testResult" name="check" class="ml-2 mr-1 text-success"></icon>
            <icon v-if="testResult !== null && !testResult" name="times" class="ml-2 mr-1 text-danger"></icon>
          </b-button>
          <b-button-group
            @click="toggleVisibility()"
            @mouseover="startVisibility()"
            @mousemove="startVisibility()"
            @mouseout="stopVisibility()"
          >
            <b-button class="input-group-text" :disabled="!this.inputValue" :pressed="showPassword" tabindex="-1"><icon name="eye"></icon></b-button>
          </b-button-group>
        </b-button-group>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
    <b-popover
      triggers="focus blur click"
      placement="bottom"
      :target="uuid"
      :title="$t('Generate password')"
      :show.sync="showGenerator"
      @shown="showingGenerator = true"
      @hidden="showingGenerator = false">
      <div ref="generator">
        <b-form-row>
          <b-col><b-form-input v-model="options.pwlength" type="range" min="6" max="32"></b-form-input></b-col>
          <b-col>{{ $t('{count} characters', { count: options.pwlength }) }}</b-col>
        </b-form-row>
        <b-form-row>
          <b-col><b-form-checkbox v-model="options.upper">ABC</b-form-checkbox></b-col>
          <b-col><b-form-checkbox v-model="options.lower">abc</b-form-checkbox></b-col>
        </b-form-row>
        <b-form-row>
          <b-col><b-form-checkbox v-model="options.digits">123</b-form-checkbox></b-col>
          <b-col><b-form-checkbox v-model="options.special">!@#</b-form-checkbox></b-col>
        </b-form-row>
        <b-form-row>
          <b-col><b-form-checkbox v-model="options.brackets">({&lt;</b-form-checkbox></b-col>
          <b-col><b-form-checkbox v-model="options.high">äæ±</b-form-checkbox></b-col>
        </b-form-row>
        <b-form-row>
          <b-col><b-form-checkbox v-model="options.ambiguous">0Oo</b-form-checkbox></b-col>
        </b-form-row>
        <b-form-row>
          <b-col class="text-right"><b-button variant="primary" size="sm" @click="generatePassword()" @mouseover="startVisibility()" @mousemove="startVisibility()" @mouseout="stopVisibility()">{{ $t('Generate') }}</b-button></b-col>
        </b-form-row>
      </div>
    </b-popover>
  </b-form-group>
</template>

<script>
import pfMixinForm from '@/components/pfMixinForm'
import password from '@/utils/password'
import uuidv4 from 'uuid/v4'

export default {
  name: 'pf-form-password',
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
      type: Number,
      default: 3
    },
    text: {
      type: String,
      default: null
    },
    test: {
      type: Function,
      default: null
    },
    isLoading: {
      type: Boolean,
      default: false
    },
    disabled: {
      type: Boolean,
      default: false
    },
    generate: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      showPassword: false,
      isFocus: false,
      testResult: null,
      testMessage: null,
      isTesting: false,
      showGenerator: false,
      showingGenerator: false,
      options: {
        pwlength: 8,
        upper: true,
        lower: true,
        digits: true,
        special: false,
        brackets: false,
        high: false,
        ambiguous: false
      },
      uuid: uuidv4() // unique id for multiple instances of this component
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
    },
    type () {
      return (this.showPassword) ? 'text' : 'password'
    },
    mouseDown () {
      return this.$store.getters['events/mouseDown']
    },
    allowTest () {
      return !this.isLoading && !this.isTesting && this.inputValue && this.inputState !== false
    }
  },
  methods: {
    focus () {
      this.$refs.input.focus()
    },
    startVisibility () {
      this.showPassword = true
    },
    stopVisibility () {
      this.showPassword = false
    },
    toggleVisibility () {
      this.showPassword = !this.showPassword
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
    },
    resetTest () {
      this.testResult = null
      this.testMessage = null
    },
    generatePassword () {
      this.inputValue = password.generate(this.options)
    }
  },
  watch: {
    mouseDown (pressed) {
      if (pressed && this.showingGenerator) {
        const $event = this.$store.getters['events/mouseEvent']
        this.showGenerator = this.$refs.generator.contains($event.target)
      }
    }
  }
}
</script>

<style lang="scss" scoped>
/**
 * Adjust is-invalid and is-focus borders
 */
.pf-form-password {
  .pf-form-password-input-group {
    padding: 1px;
    border: 1px solid $input-focus-bg;
    background-color: $input-focus-bg;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    outline: 0;

    * {
      border: 0px;
    }
    &:not(:first-child):not(:last-child):not(:only-child),
    &.btn-group:first-child {
      border-radius: 0;
    }
    &:first-child {
      border-top-left-radius: $border-radius;
      border-bottom-left-radius: $border-radius;
    }
    &:last-child {
      border-top-right-radius: $border-radius;
      border-bottom-right-radius: $border-radius;
    }
  }
  &.is-focus .pf-form-password-input-group {
    border: 1px solid $input-focus-border-color;
    box-shadow: 0 0 0 $input-focus-width rgba($input-focus-border-color, .25);
  }
  &.is-invalid .pf-form-password-input-group {
    border: 1px solid $form-feedback-invalid-color;
    box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-invalid-color, .25);
  }
}

/**
 * Add btn-primary color(s) on hover
 */
.btn-group[rel=testResultGroup] button {
  opacity: 1;
  text-transform: none;
}
.btn-group[rel=prefixButtonGroup] button:hover:not(.disabled) {
  background-color: $input-btn-hover-bg-color;
  color: $input-btn-hover-text-color;
  border-color: $input-btn-hover-bg-color;
  cursor: pointer;
}
</style>
