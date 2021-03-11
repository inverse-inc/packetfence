<!--
 * Component to pick datetime.
 *
 * Optional Properties:
 *    v-model: reactive property getter/setter
 *    value: default value
 *    label: form-group label
 *    placeholder: input placeholder
 *    prependText: input-group prepend slot
 *    config: extend/overload flatpickr options
 *      See: https://flatpickr.js.org/options/
 *    disabled: (Boolean) true/false to disable/enable input
 *    min: (Date) minimum datetime string
 *    max: (Date) maximum datetime String
 *    moments: button array of +/- seconds from now (see: https://date-fns.org/v1.29.0/docs/addSeconds)
 *      example :moments="['-1 hours', '1 hours', '1 days', '1 weeks', '1 months', '1 quarters', '1 years']"
 -->
 <template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="inputState"
    class="pf-form-datetime" :class="{ 'mb-0': !columnLabel, 'is-focus': isFocus}">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!inputInvalidFeedback"></icon> {{ inputInvalidFeedback }}
    </template>
    <b-input-group class="pf-form-datetime-input-group">
      <b-input-group-prepend v-if="prependText">
        <div class="input-group-text">
          {{ prependText }}
        </div>
      </b-input-group-prepend>
      <b-form-input ref="userInput"
        v-model="inputValue"
        v-bind="$attrs"
        :state="inputState"
        :disabled="disabled"
        :readonly="readonly"
        @click="onClick($event)"
        @focus="onFocus($event)"
        @blur="onBlur($event)"
      />
      <b-input-group-append>
        <b-button-group v-if="moments.length > 0" rel="moments" v-b-tooltip.hover.top.d300 :title="$t('Cumulate [CTRL/CMD] + [CLICK]')">
          <b-button v-for="(moment, index) in moments" :key="index" variant="light" @click="onClickMoment($event, index)" v-b-tooltip.hover.bottom.d300 :title="momentTooltip(index)" tabindex="-1">{{ momentLabel(index) }}</b-button>
        </b-button-group>
        <b-button class="input-group-text" @click.stop.prevent="open($event)" tabindex="-1">
          <icon :name="(formatIsTimeOnly()) ? 'clock' : 'calendar-alt'" variant="light"></icon>
          <!-- hidden -->
          <flat-pickr ref="flatpickrInput"
            :key="locale"
            :value="flatpickrValue"
            :config="flatpickrConfig"
            @on-change="onChange($event)"
          ></flat-pickr>
        </b-button>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinForm from '@/components/pfMixinForm'
import flatPickr from 'vue-flatpickr-component'
import 'flatpickr/dist/flatpickr.css'
import 'flatpickr/dist/themes/material_blue.css'
import { english } from 'flatpickr/dist/l10n/default.js'
import { French } from 'flatpickr/dist/l10n/fr.js'
import {
  parse,
  format,
  isValid,
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
  components: {
    flatPickr
  },
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
    prependText: {
      type: String
    },
    config: {
      type: Object,
      default: () => ({})
    },
    min: {
      type: [String, Number]
    },
    max: {
      type: [String, Number]
    },
    moments: {
      type: Array,
      default: () => []
    },
    disabled: {
      type: Boolean,
      default: false
    },
    readonly: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      defaults: {
        allowInput: true,
        datetimeFormat: 'YYYY-MM-DD HH:mm:ss',
        time_24hr: true,
        wrap: true
      },
      isFocus: false,
      localMin: null,
      localMax: null
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
      set (newValue) {
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.$emit('input', newValue) // use native (v-model)
        }
      }
    },
    inputElement () {
      const { $refs: { userInput } = {} } = this
      return userInput
    },
    flatpickrValue: {
      get () {
        let { inputValue, options: { datetimeFormat } = {} } = this
        if (inputValue) {
          inputValue = inputValue.trim()
          let length = this.inputValue.trim().length
          let inspect = [...datetimeFormat.match(/[a-z]+/gi).map(set => datetimeFormat.indexOf(set) + set.length)]
          if (inspect.includes(inputValue.length)) {
            if (this.inputValue.trim().replace(/[0-9]/g, '0') === datetimeFormat.slice(0, length).replace(/[a-z]/gi, '0')) {
              return format(this.inputValue.trim(), datetimeFormat)
            }
          }
        }
        return undefined
      },
      set () {
        //  don't do anything here, instead use the `on-change` event => `onChange` method
      }
    },
    flatpickrElement () {
      const { $refs: { flatpickrInput: { fp } = {} } = {} } = this
      return fp
    },
    flatpickrConfig () {
      let extraConfig = {
        minDate: (!this.localMin) ? new Date(-8640000000000000) : this.localMin,
        maxDate: (!this.localMax) ? new Date(8640000000000000) : this.localMax
      }
      let config = { ...this.options, ...extraConfig }
      if ('datetimeFormat' in config) {
        config.datetimeFormat = this.convertFormat(config.datetimeFormat)
        if (/[HhGiSsK]+/.test(config.datetimeFormat)) {
          config.enableTime = true
          config.enableSeconds = true
        } else {
          config.enableTime = false
          config.enableSeconds = false
        }
        if (/[YyFMmndJjlD]+/.test(config.datetimeFormat)) {
          config.noCalendar = false
        } else {
          config.noCalendar = true
        }
      }
      switch (this.locale) {
        case 'fr':
          config.locale = French
          break
        case 'en':
        default:
          config.locale = english
          break
      }
      config.dateFormat = config.datetimeFormat // rename datetimeFormat to dateFormat (flatpickr)
      delete config.datetimeFormat
      return config
    },
    locale () {
      return this.$i18n.locale
    },
    options () {
      return { ...this.defaults, ...this.config }
    }
  },
  methods: {
    onChange (event) {
      if (this.closeTimeout) {
        clearTimeout(this.closeTimeout)
      }
      const { 0: newDatetime } = event
      if (newDatetime && this.isFocus === false) { // only accept mutations when inputElement is not focused
        const now = (new Date()).getTime()
        if (now > newDatetime.getTime() && now - newDatetime.getTime() < 1E3) {
          // ignore, flatpickr is attempting to set current date/time
        }
        else {
          const { options: { datetimeFormat } = {} } = this
          this.inputValue = format(newDatetime, datetimeFormat)
        }
      }
    },
    onClick () {
      this.isFocus = true
      if (this.closeTimeout) {
        clearTimeout(this.closeTimeout)
      }
      this.open()
    },
    onFocus () {
      this.isFocus = true
      if (this.closeTimeout) {
        clearTimeout(this.closeTimeout)
      }
      this.open()
      this.inputElement.select()
    },
    onBlur () {
      this.isFocus = false
      if (this.closeTimeout) {
        clearTimeout(this.closeTimeout)
      }
      this.closeTimeout = setTimeout(() => {
        this.close()
      }, 500)
    },
    open () {
      this.flatpickrElement.open()
    },
    close () {
      this.flatpickrElement.close()
    },
    clear () {
      this.flatpickrElement.clear()
    },
    convertFormat (format = 'YYYY-MM-DD HH:ii:ss') {
      // converts 'datefns' format to 'flatpickr' format
      //  https://flatpickr.js.org/formatting/
      [
        ['YYYY', 'Y'], // 4 digit year (1973)
        ['YY', 'y'], // 2 digit year (73)
        ['MMMM', 'F'], // January, February, ..., December
        ['MMM', 'M'], // Jan, Feb, ..., Dec
        ['MM', 'm'], // 2 digit month (01-31)
        ['M', 'n'], // 1-2 digit month (1-31)
        ['DD', 'd'], // 2 digit day (01-31)
        ['Do', 'J'], // 1st, 2nd, ..., 31st
        ['D', 'j'], // 1-2 digit day (1-31)
        ['dddd', 'l'], // Sunday, Monday, ..., Saturday
        ['ddd', 'D'], // Sun, Mon, ..., Sat
        ['HH', 'H'], // 2 digit hour (01-23)
        // ['h', 'h'], // 1 digit hour (1-23)
        ['mm', 'i'], // 2 digit minute (00-59)
        ['ss', 'S'], // 2 digit seconds (00-59)
        // ['s', 's'], // 1 digit seconds (0-59)
        ['X', 'U'], // seconds since epoch
        ['A', 'K'] // AM or PM
      ].forEach((replace) => {
        const [ from, to ] = replace
        format = format.replace(from, to)
      })
      return format
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
    onClickMoment (event, index) {
      let [amount, key] = this.moments[index].split(' ', 2)
      amount = parseInt(amount)
      // allow [CTRL/CMD]+[CLICK] for cumulative change
      const datetimeFormat = this.config.datetimeFormat || this.defaults.datetimeFormat
      const base = (event.ctrlKey || event.metaKey) ? parse(this.inputValue, datetimeFormat) || new Date() : new Date()
      if (validMomentKeys.includes(key)) {
        switch (key) {
          case 'years':
            this.inputValue = format(addYears(base, amount), datetimeFormat)
            break
          case 'quarters':
            this.inputValue = format(addQuarters(base, amount), datetimeFormat)
            break
          case 'months':
            this.inputValue = format(addMonths(base, amount), datetimeFormat)
            break
          case 'weeks':
            this.inputValue = format(addWeeks(base, amount), datetimeFormat)
            break
          case 'days':
            this.inputValue = format(addDays(base, amount), datetimeFormat)
            break
          case 'hours':
            this.inputValue = format(addHours(base, amount), datetimeFormat)
            break
          case 'minutes':
            this.inputValue = format(addMinutes(base, amount), datetimeFormat)
            break
          case 'seconds':
            this.inputValue = format(addSeconds(base, amount), datetimeFormat)
            break
          case 'milliseconds':
            this.inputValue = format(addMilliseconds(base, amount), datetimeFormat)
            break
          default:
            this.inputValue = format(base, datetimeFormat)
        }
      }
    },
    formatIsTimeOnly () {
      let datetimeFormat = this.flatpickrConfig.datetimeFormat
      if ('input' in this.$refs && 'dp' in this.$refs.input) {
        return !(/[MQDdEeWwYgX]+/.test(datetimeFormat))
      }
      return false
    }
  },
  created () {
    const datetimeFormat = this.options.datetimeFormat
    if (this.inputValue instanceof Date) {
      // instanceof Date, convert to String
      this.inputValue = format(this.inputValue, datetimeFormat)
    }
  },
  watch: {
    min: {
      handler: function (a) {
        this.localMin = (a)
          ? parse(format((a instanceof Date && isValid(a) ? a : parse(a)), this.options.datetimeFormat))
          : null
      },
      immediate: true
    },
    max: {
      handler: function (a) {
        this.localMax = (a)
          ? parse(format((a instanceof Date && isValid(a) ? a : parse(a)), this.options.datetimeFormat))
          : null
      },
      immediate: true
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
    .flatpickr-input {
      display: flex;
      position: absolute;
      bottom: 0;
      right: 0;
      width: 100%;
      height: 100%;
      visibility: hidden;
      border: 0;
      margin: 0;
      outline: 0;
    }
  }
  &.is-focus .pf-form-datetime-input-group {
    border: 1px solid $input-focus-border-color;
    .flatpickr-input {
      border-right: 2px solid $input-focus-border-color;
    }
  }
  &.is-invalid .pf-form-datetime-input-group {
    border: 1px solid $form-feedback-invalid-color;
    .flatpickr-input {
      border-right: 2px solid $form-feedback-invalid-color;
    }
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

/**
 * Override default flatpickr styles
 */
.flatpickr-calendar.arrowTop:after {
  border-bottom-color: $primary;
}
.flatpickr-calendar.arrowBottom:after {
  border-top-color: $primary;
}
.flatpickr-months .flatpickr-month {
  background: $primary;
}
.flatpickr-current-month .flatpickr-monthDropdown-months {
  background: $primary;
}
.flatpickr-current-month .flatpickr-monthDropdown-months .flatpickr-monthDropdown-month {
  background-color: $primary;
}
.flatpickr-weekdays {
  background: $primary;
}
span.flatpickr-weekday {
  background: $primary;
  color: $white;
}
.flatpickr-day.selected,
.flatpickr-day.startRange,
.flatpickr-day.endRange,
.flatpickr-day.selected.inRange,
.flatpickr-day.startRange.inRange,
.flatpickr-day.endRange.inRange,
.flatpickr-day.selected:focus,
.flatpickr-day.startRange:focus,
.flatpickr-day.endRange:focus,
.flatpickr-day.selected:hover,
.flatpickr-day.startRange:hover,
.flatpickr-day.endRange:hover,
.flatpickr-day.selected.prevMonthDay,
.flatpickr-day.startRange.prevMonthDay,
.flatpickr-day.endRange.prevMonthDay,
.flatpickr-day.selected.nextMonthDay,
.flatpickr-day.startRange.nextMonthDay,
.flatpickr-day.endRange.nextMonthDay {
  background: $primary;
  border: $primary;
}
.flatpickr-day.selected.startRange + .endRange:not(:nth-child(7n+1)),
.flatpickr-day.startRange.startRange + .endRange:not(:nth-child(7n+1)),
.flatpickr-day.endRange.startRange + .endRange:not(:nth-child(7n+1)) {
  box-shadow: -10px 0 0 $primary;
}
.flatpickr-day.week.selected {
  border-radius: 0;
  box-shadow: -5px 0 0 $primary, 5px 0 0 $primary;
}
</style>
