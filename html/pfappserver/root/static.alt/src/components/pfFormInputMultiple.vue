<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="isValid()"
    class="pf-form-input-multiple" :class="{ 'mb-0': !columnLabel, 'is-focus': focus, 'is-empty': !value, 'is-disabled': disabled }">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!getInvalidFeedback()"></icon> {{ feedbackState }}
    </template>
    <b-input-group>
      <multiselect
        v-model="inputValue"
        v-bind="$attrs"
        v-on="forwardListeners"
        ref="input"
        :disabled="disabled"
        :state="isValid()"
        label="text"
        track-by="value"
        :multiple="true"
        :options="options"
        :taggable="true"
        :placeholder="proxyPlaceholder"
        :tag-placeholder="proxyTagPlaceholder"
        @tag="addTag"
        @change.native="onChange($event)"
        @input.native="validate()"
        @keyup.native.stop.prevent="onChange($event)"
        @open="onFocus"
        @close="onBlur"
      ></multiselect>
      <b-input-group-append v-if="readonly || disabled">
        <b-button v-if="readonly || disabled" class="input-group-text" tabindex="-1" disabled><icon name="lock"></icon></b-button>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import Multiselect from 'vue-multiselect'
import 'vue-multiselect/dist/vue-multiselect.min.css'
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-input-multiple',
  mixins: [
    pfMixinValidation
  ],
  components: {
    Multiselect
  },
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
    separator: {
      type: String,
      default: ','
    },
    placeholder: {
      type: String,
      default: null
    },
    tagPlaceholder: {
      type: String,
      default: null
    }
  },
  data () {
    return {
      hasFocus: false
    }
  },
  computed: {
    inputValue: {
      get () {
        let inputValue = ((this.value)
          ? this.value
            .split(this.separator.trim())
            .filter(value => value)
            .map(value => { return { text: value.trim(), value: value.trim() } })
          : []
        )
        return inputValue
      },
      set (newValue) {
        this.$emit('input', newValue.map(value => value.value).filter(value => value).join(this.separator) || null)
      }
    },
    options () {
      return this.inputValue
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    },
    proxyPlaceholder () {
      return (this.hasFocus)
        ? this.placeholder || this.$i18n.t('Enter a new value')
        : '' // hide placeholder when not in focus
    },
    proxyTagPlaceholder () {
      return this.tagPlaceholder || this.$i18n.t('Click to add value')
    }
  },
  methods: {
    onFocus () {
      this.hasFocus = true
    },
    onBlur () {
      this.hasFocus = false
    },
    focus () {
      this.$refs.input.focus()
    },
    addTag (newTag) {
      this.$set(this, 'inputValue', [ ...this.inputValue, ...[{ text: newTag, value: newTag }] ])
    }
  }
}
</script>

<style lang="scss">
/**
 * Adjust is-invalid and is-focus borders
 */
.pf-form-input-multiple {

  /* show placeholder even when empty */
  &.is-empty {
    .multiselect__input,
    .multiselect__placeholder {
      position: relative !important;
      width: 100% !important;
    }
    .multiselect__placeholder {
      display: none;
    }
  }
  &.is-empty:not(.is-focus) {
    .multiselect__single {
      display: none;
    }
  }

  .multiselect__loading-enter-active,
  .multiselect__loading-leave-active,
  .multiselect__input,
  .multiselect__single,
  .multiselect__tags,
  .multiselect__tag-icon,
  .multiselect__select,
  .multiselect-enter-active,.multiselect-leave-active {
    transition: $custom-forms-transition;
  }

  .multiselect {
      position: relative;
      flex: 1 1 auto;
      width: 1%;
      min-height: auto;
      border-width: 1px;
      margin-bottom: 0;
      font-size: $font-size-base;
  }
  .multiselect__tags,
  .multiselect__option {
    min-height: $input-height;
    padding: $input-padding-y $input-padding-x;
    font-size: $font-size-base;
    line-height: $input-line-height;
  }
  .multiselect__tags {
    padding: 4px 40px 4px 4px;
    border: 1px solid $input-focus-bg;
    background-color: $input-focus-bg;
    @include border-radius($border-radius);
    outline: 0;
    .multiselect__tags-wrap {
      padding: 0;
    }
    .multiselect__input {
      max-width: 100%;
    }
    span > span.multiselect__single { /* placeholder */
      color: $input-placeholder-color;
      // Override Firefox's unusual default opacity; see https://github.com/twbs/bootstrap/pull/11526.
      opacity: 1;
    }
  }
  .multiselect__select {
    top: 0px;
    right: 10px;
    bottom: 0px;
    width: auto;
    height: auto;
    padding: 0px;
  }
  .multiselect__tag {
    margin: 2px;
    background-color: $secondary;
    overflow: unset;
    /*
    text-overflow: unset;
    */
  }
  .multiselect__tag-icon {
    &:hover {
      background-color: inherit;
      color: lighten($secondary, 15%);
    }
    &:after {
      color: $component-active-color;
    }
  }
  .multiselect__input,
  .multiselect__single {
    padding: 0px;
    margin: 4px;
    background-color: transparent;
    color: $input-color;
    font-size: $font-size-base;
    &::placeholder {
      color: $input-placeholder-color;
    }
  }
  .multiselect__placeholder {
    padding-top: 0px;
    padding-bottom: $input-padding-y;
    margin-bottom: 0px;
    color: $input-placeholder-color;
    font-size: $font-size-base;
    line-height: $input-line-height;
  }
  .multiselect__content-wrapper {
    z-index: $zindex-popover;
    border: $dropdown-border-width solid $dropdown-border-color;
    @include border-radius($dropdown-border-radius);
    @include box-shadow($dropdown-box-shadow);
  }
  .multiselect--active:not(.multiselect--above) {
    .multiselect__content-wrapper {
      border-top-width: 0px;
      border-bottom-width: 1px;
      border-top-left-radius: 0 !important;
      border-top-right-radius: 0 !important;
      border-bottom-left-radius: $border-radius !important;
      border-bottom-right-radius: $border-radius !important;
    }
  }
  .multiselect--above {
    .multiselect__content-wrapper {
      border-bottom-width: 0px;
      border-bottom-left-radius: 0 !important;
      border-bottom-right-radius: 0 !important;
    }
  }
  .multiselect__option--highlight {
    color: $dropdown-link-active-color;
  }
  .multiselect--disabled {
    background-color: $input-disabled-bg;
    opacity: 1;
    .multiselect__tags,
    .multiselect__single {
      background-color: $input-disabled-bg;
    }
    .multiselect__select {
      background-color: transparent;
    }
  }
  &.is-focus {
    .multiselect__tags {
      border-color: $input-focus-border-color;
    }
  }
  &.is-invalid {
    .multiselect__tags {
      border-color: $form-feedback-invalid-color;
    }
  }
}
</style>
