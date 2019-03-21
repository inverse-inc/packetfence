<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
    class="pf-form-password" :class="{ 'mb-0': !columnLabel, 'is-focus': focus }">
    <b-input-group class="pf-form-password-input-group">
      <b-form-input
        v-model="inputValue"
        v-bind="$attrs"
        ref="input"
        :type="type"
        :state="isValid()"
        @input.native="validate()"
        @keyup.native="resetTest($event)"
        @change.native="onChange($event)"
        @focus.native="focus = true"
        @blur.native="focus = false"
      >
      </b-form-input>
      <b-input-group-append>
        <b-button-group v-if="test" rel="testResultGroup">
          <b-button v-if="testResult !== null" variant="light" disabled tabindex="-1">
            <span class="mr-1" :class="{ 'text-danger': !testResult, 'text-success': testResult }">{{ testMessage }}</span>
          </b-button>
        </b-button-group>
        <b-button-group rel="prefixButtonGroup">
          <b-button v-if="test" class="input-group-text" @click="runTest()" :disabled="isLoading || isTesting || !this.value" tabindex="-1">
            {{ $t('Test') }}
            <icon v-show="isTesting" name="circle-notch" spin class="ml-2 mr-1"></icon>
            <icon v-if="testResult !== null && testResult" name="check" class="ml-2 mr-1 text-success"></icon>
            <icon v-if="testResult !== null && !testResult" name="times" class="ml-2 mr-1 text-danger"></icon>
          </b-button>
          <b-button class="input-group-text" @click="toggleVisibility()" @mouseover="startVisibility()" @mousemove="startVisibility()" @mouseout="stopVisibility()" :disabled="!this.value && this.type === 'password'" :pressed="showPassword" tabindex="-1"><icon name="eye"></icon></b-button>
        </b-button-group>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-password',
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
    type: {
      type: String,
      default: 'password'
    },
    test: {
      type: Function,
      default: null
    },
    isLoading: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      showPassword: false,
      focus: false,
      testResult: null,
      testMessage: null,
      isTesting: false
    }
  },
  computed: {
    inputValue: {
      get () {
        return this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    }
  },
  methods: {
    startVisibility () {
      this.type = 'text'
    },
    stopVisibility () {
      this.type = (this.showPassword) ? 'text' : 'password'
    },
    toggleVisibility () {
      if (this.showPassword) {
        this.type = 'password' // hide password
      } else {
        this.type = 'text' // show password
      }
      this.showPassword = !this.showPassword
    },
    runTest () {
      if (this.test) {
        this.isTesting = true
        this.testResult = null
        this.test().then(response => {
          this.testResult = true
          this.$emit('pass')
          this.testMessage = null
          this.isTesting = false
        }).catch(err => {
          this.testResult = false
          if ('data' in err.response) {
            this.$emit('fail', err.response.data)
            if ('message' in err.response.data) {
              this.testMessage = err.response.data.message
            }
            this.isTesting = false
          }
        })
      }
    },
    resetTest (event) {
      this.testResult = null
      this.testMessage = null
      this.onChange(event)
    }
  }
}
</script>

<style lang="scss" scoped>
@import "../../node_modules/bootstrap/scss/functions";
@import "../../node_modules/bootstrap/scss/mixins/border-radius";
@import "../../node_modules/bootstrap/scss/mixins/transition";
@import "../styles/variables";

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
.btn-group[rel=prefixButtonGroup] button:hover {
  background-color: $input-btn-hover-bg-color;
  color: $input-btn-hover-text-color;
  border-color: $input-btn-hover-bg-color;
}
</style>
