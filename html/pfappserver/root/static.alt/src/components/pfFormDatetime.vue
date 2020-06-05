<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="inputState"
    class="pf-form-datetime" :class="{ 'mb-0': !columnLabel, 'is-focus': isFocus }">
    <template v-slot:invalid-feedback>
      {{ inputInvalidFeedback }}
    </template>
    <b-input-group class="pf-form-datetime-input-group">
      <b-input-group-prepend v-if="prependText">
        <div class="input-group-text">
          {{ prependText }}
        </div>
      </b-input-group-prepend>
      <b-form-input ref="inputElement"
        :id="`input-${formNamespace}`"
        v-model="inputValue"
        type="text"
        :disabled="disabled"
        :readonly="readonly"
        :placeholder="placeholder || format"
        autocomplete="off"
        @keydown="onFocusInput($event)"
        @click="onFocusInput($event)"
        @focus="onFocusInput($event)"
        @blur="onBlurInput($event)"
      ></b-form-input>
      <b-popover :show.sync="isFocus"
        custom-class="popover-full"
        placement="top"
        triggers="manual"
        :target="`input-${formNamespace}`"
      >
        <template v-slot:title>
          <b-row class="small">
            <b-col cols="auto">
              {{ (formatHasDate) ? $t('Choose Date') : $t('Choose Time') }}
            </b-col>
            <b-col cols="auto" class="ml-auto text-secondary">
              {{ format }}
            </b-col>
          </b-row>
        </template>
        <b-row class="text-center" no-gutters v-if="formatHasDate">
          <b-col cols="12" class="text-center p-2" :class="{ 'pb-3': formatHasTime }"
            v-on:click="onEventVacuum($event)"
            v-on:mousedown="onEventVacuum($event)"
          >
            <b-calendar
              v-model="dateValue"
              class="align-self-center"
              :locale="$i18n.locale"
              :min="dateValueMin"
              :max="dateValueMax"
              @selected="onDateSelected"
              label-help=""
              hide-header
              block
            ></b-calendar>
          </b-col>
        </b-row>
        <b-row class="text-center" no-gutters v-if="formatHasTime">
          <b-col cols="12" class="text-center p-2" :class="{ 'pt-3 border-top': formatHasDate }"
            v-on:click="onEventVacuum($event)"
            v-on:mousedown="onEventVacuum($event)"
          >
            <b-time
              v-model="timeValue"
              class="align-self-center"
              :locale="$i18n.locale"
              :seconds-step="(actionKey) ? 10 : 1"
              :minutes-step="(actionKey) ? 10 : 1"
              @context="onTimeContext"
              hide-header
              show-seconds
            ></b-time>
          </b-col>
        </b-row>
      </b-popover>
      <b-input-group-append>
        <b-button-group v-if="moments.length > 0" rel="moments" v-b-tooltip.hover.top.d300 :title="$t('Cumulate [CTRL/CMD] + [CLICK]')">
          <b-button v-for="(moment, index) in moments" :key="index" variant="light" @click="onClickMoment(index)" v-b-tooltip.hover.bottom.d300 :title="momentTooltip(index)" tabindex="-1">{{ momentLabel(index) }}</b-button>
        </b-button-group>
        <b-button class="input-group-text" @click.stop.prevent="onToggleFocus($event)" tabindex="-1">
          <icon :name="formatHasDate ? 'calendar-alt' : 'clock'" variant="light"></icon>
        </b-button>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-show="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinForm from '@/components/pfMixinForm'
import {
  parse,
  format,
  isValid,
  getHours,
  getMinutes,
  getSeconds,
  setHours,
  setMinutes,
  setSeconds,
  addYears,
  addQuarters,
  addMonths,
  addWeeks,
  addDays,
  addHours,
  addMinutes,
  addSeconds,
  addMilliseconds
} from 'date-fns'

// even indexes (0, 2, ...) must be full names, odd (1, 3, ...) indexes must be abbreviations
const validMomentKeys = ['years', 'y', 'quarters', 'Q', 'months', 'M', 'weeks', 'w', 'days', 'd', 'hours', 'h', 'minutes', 'm', 'seconds', 's', 'milliseconds', 'ms']

export default {
  name: 'pf-form-datetime',
  mixins: [
    pfMixinForm
  ],
  data () {
    return {
      isFocus: false
    }
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
    prependText: {
      type: String
    },
    min: {
      type: String
    },
    max: {
      type: String
    },
    moments: {
      type: Array,
      default: () => []
    },
    format: {
      type: String,
      default: 'YYYY-MM-DD HH:mm:ss'
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
    inputElement () {
      const { $refs: { inputElement } = {} } = this
      return inputElement
    },
    dateValue: {
      get () {
        // b-calendar expects Date()
        if (this.inputValue) {
          let dateValue = parse(this.inputValue, this.format)
          dateValue = setHours(dateValue, 0)
          dateValue = setMinutes(dateValue, 0)
          dateValue = setSeconds(dateValue, 0)
          return dateValue
        }
        else {
          return (new Date(new Date().setHours(0, 0, 0, 0)))
        }
      }
    },
    dateValueMin () {
      if (this.min) {
        if (this.min.constructor === Date) {
          return this.min
        }
        let dateValue = parse(this.min, this.format)
        dateValue = setHours(dateValue, 0)
        dateValue = setMinutes(dateValue, 0)
        dateValue = setSeconds(dateValue, 0)
        return dateValue
      }
      return false
    },
    dateValueMax () {
      if (this.max) {
        if (this.max.constructor === Date) {
          return this.max
        }
        let dateValue = parse(this.max, this.format)
        dateValue = setHours(dateValue, 0)
        dateValue = setMinutes(dateValue, 0)
        dateValue = setSeconds(dateValue, 0)
        return dateValue
      }
      return false
    },
    timeValue: {
      get () {
        // b-time expects String w/ format 'HH:mm:ss'
        if (this.inputValue) {
          let inputValue
          if (this.formatHasDate) {
            inputValue = parse(this.inputValue, this.format)
          }
          else {
            // date-fns does not parse only a time format (eg: 'HH:mm:ss'),
            //  workaround by adding a known prefix
            inputValue = parse(`1973-01-01 ${this.inputValue}`, `YYYY-MM-DD ${this.format}`)
          }

          let formattedValue = format(inputValue, 'HH:mm:ss')
          if (this.inputValue.includes(formattedValue)) {
            return formattedValue
          }
        }
        return null
      }
    },
    formatHasDate () {
      return /[YMDd]+/.test(this.format)
    },
    formatHasTime () {
      return /[HmsXA]+/.test(this.format)
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
    }
  },
  methods: {
    focus () {
      this.inputElement.focus()
    },
    onFocusInput (event) {
      if (this.onBlurInputTimeout) {
        clearTimeout(this.onBlurInputTimeout)
      }
      this.isFocus = true
    },
    onBlurInput (event) {
      if (this.onBlurInputTimeout) {
        clearTimeout(this.onBlurInputTimeout)
      }
      this.onBlurInputTimeout = setTimeout(() => { // wait for b-calendar context
        this.isFocus = false
      }, 300)
    },
    onEventVacuum (event) {
      // popover component event, focus was stolen, defer onBlur
      if (this.onBlurInputTimeout) {
        clearTimeout(this.onBlurInputTimeout)
        setTimeout(() => {
          clearTimeout(this.onBlurInputTimeout)
        }, 300)
      }
      if (this.isFocus) {
        this.inputElement.focus() // refocus
      }
    },
    onToggleFocus (event) {
      if (this.isFocus) {
        this.inputElement.blur()
      }
      else {
        this.inputElement.focus()
      }
    },
    onDateSelected (date) {
      let selectedDate = parse(date, 'YYYY-MM-DD') // b-calendar uses 'YYYY-MM-DD' format
      if (selectedDate) {
        if (this.inputValue && this.formatHasTime) {
          let parsedInputValue = parse(this.inputValue, this.format)
          selectedDate = addHours(selectedDate, getHours(parsedInputValue))
          selectedDate = addMinutes(selectedDate, getMinutes(parsedInputValue))
          selectedDate = addSeconds(selectedDate, getSeconds(parsedInputValue))
        }
        this.inputValue = format(selectedDate, this.format)
      }
    },
    onTimeContext (context) {
      if (this.onBlurInputTimeout) { // don't blur input
        clearTimeout(this.onBlurInputTimeout)
      }
      if (this.isFocus) {
        this.inputElement.focus() // refocus
      }
      let selectedDate
      const { hours, minutes, seconds } = context
      if (hours !== null || minutes !== null || seconds !== null) {
        if (this.inputValue && this.formatHasDate) {
          selectedDate = parse(this.inputValue, this.format)
          selectedDate = setHours(selectedDate, hours || 0)
          selectedDate = setMinutes(selectedDate, minutes || 0)
          selectedDate = setSeconds(selectedDate, seconds || 0)
        }
        else {
          selectedDate = (new Date(new Date().setHours(hours || 0, minutes || 0, seconds || 0, 0)))
        }
        this.inputValue = format(selectedDate, this.format)
      }
    },
    momentTooltip (index) {
      let [amount, key] = this.moments[index].split(' ', 2)
      amount = parseInt(amount)
      if (validMomentKeys.includes(key)) {
        let i = validMomentKeys.indexOf(key)
        if (i % 2) {
          // is odd, shift index left, use full key name
          i -= 1
        }
        let text = validMomentKeys[i]
        if ([-1, 1].includes(amount)) {
          // singular, drop trailing 's'
          text = text.slice(0, -1)
        }
        if (amount < 0) {
          return this.$i18n.t('{num} {unit} ago', { num: -amount.toString(), unit: this.$i18n.t(text) })
        } else {
          return this.$i18n.t('{num} {unit} from now', { num: amount.toString(), unit: this.$i18n.t(text) })
        }
      }
      return null
    },
    momentLabel (index) {
      let [amount, key] = this.moments[index].split(' ', 2)
      if (validMomentKeys.includes(key)) {
        let i = validMomentKeys.indexOf(key)
        if (i % 2 === 0) {
          // is even, shift index right, use abbreviated key name
          i += 1
        }
        let abbr = validMomentKeys[i]
        return ((amount > 0) ? '+' : '') + amount.toString() + abbr.toUpperCase()
      }
      return null
    },
    onClickMoment (index) {
      let [amount, key] = this.moments[index].split(' ', 2)
      amount = parseInt(amount)
      // allow [CTRL/CMD]+[CLICK] for cumulative change
      let base
      if (this.formatHasDate) {
        base = (this.actionKey)
          ? parse(this.inputValue, this.format) || new Date()
          : new Date()
      }
      else {
        // date-fns does not parse only a time format (eg: 'HH:mm:ss'),
        //  workaround by adding a known prefix
        base = (this.actionKey)
          ? parse(`1973-01-01 ${this.inputValue}`, `YYYY-MM-DD ${this.format}`) || new Date()
          : new Date()
      }
      if (validMomentKeys.includes(key)) {
        switch (key) {
          case 'years':
            this.inputValue = format(addYears(base, amount), this.format)
            break
          case 'quarters':
            this.inputValue = format(addQuarters(base, amount), this.format)
            break
          case 'months':
            this.inputValue = format(addMonths(base, amount), this.format)
            break
          case 'weeks':
            this.inputValue = format(addWeeks(base, amount), this.format)
            break
          case 'days':
            this.inputValue = format(addDays(base, amount), this.format)
            break
          case 'hours':
            this.inputValue = format(addHours(base, amount), this.format)
            break
          case 'minutes':
            this.inputValue = format(addMinutes(base, amount), this.format)
            break
          case 'seconds':
            this.inputValue = format(addSeconds(base, amount), this.format)
            break
          case 'milliseconds':
            this.inputValue = format(addMilliseconds(base, amount), this.format)
            break
          default:
            this.inputValue = format(base, this.format)
        }
      }
    }
  }
}
</script>

<style lang="scss">
/**
 * Adjust is-invalid and is-focus borders
 */
.pf-form-datetime {
  .pf-form-datetime-input-group {
    border: 1px solid $input-focus-bg;
    background-color: $input-focus-bg;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    outline: 0;

    * {
      border: 0px;
    }
    &:not(:first-child):not(:last-child):not(:only-child) {
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
  &.is-focus .pf-form-datetime-input-group {
    border: 1px solid $input-focus-border-color;
  }
  &.is-invalid .pf-form-datetime-input-group {
    border: 1px solid $form-feedback-invalid-color;
  }
}

/**
 * Add btn-primary color(s) on hover
 */
.btn-group[rel=moments] button:hover {
  border-color: $input-btn-hover-bg-color;
  border-radius: 0;
  background-color: $input-btn-hover-bg-color;
  color: $input-btn-hover-text-color;
}
</style>
