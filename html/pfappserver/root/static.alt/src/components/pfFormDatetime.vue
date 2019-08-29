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
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="isValid()"
    class="pf-form-datetime" :class="{ 'mb-0': !columnLabel, 'is-focus': focus}">
    <template slot="invalid-feedback">
      <icon name="circle-notch" spin v-if="!getInvalidFeedback()"></icon> {{ feedbackState }}
    </template>
    <b-input-group class="pf-form-datetime-input-group">
      <b-input-group-prepend v-if="prependText">
        <div class="input-group-text">
          {{ prependText }}
        </div>
      </b-input-group-prepend>
      <flat-pickr :key="locale"
        v-model="inputValue"
        v-bind="$attrs"
        ref="input"
        :config="combinedConfig"
        :state="isValid()"
        @input.native="validate()"
        @keyup.native="onChange($event)"
        @change.native="onChange($event)"
        @focus.native="focus = true"
        @blur.native="focus = false"
      ></flat-pickr>
      <b-input-group-append>
        <b-button class="input-group-text" v-if="initialValue && initialValue !== inputValue" @click.stop="reset($event)" v-b-tooltip.hover.top.d300 :title="$t('Reset')"><icon name="undo-alt" variant="light"></icon></b-button>
        <b-button-group v-if="moments.length > 0" rel="moments" v-b-tooltip.hover.top.d300 :title="$t('Cumulate [CTRL/CMD] + [CLICK]')">
          <b-button v-for="(moment, index) in moments" :key="index" variant="light" @click="onClickMoment($event, index)" v-b-tooltip.hover.bottom.d300 :title="momentTooltip(index)" tabindex="-1">{{ momentLabel(index) }}</b-button>
        </b-button-group>
        <b-button class="input-group-text" @click.stop="toggle($event)" tabindex="-1"><icon :name="(formatIsTimeOnly()) ? 'clock' : 'calendar-alt'" variant="light"></icon></b-button>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinValidation from '@/components/pfMixinValidation'
import flatPickr from 'vue-flatpickr-component'
import 'flatpickr/dist/flatpickr.css'
import 'flatpickr/dist/themes/material_blue.css'
import { english } from 'flatpickr/dist/l10n/default.js'
import { French } from 'flatpickr/dist/l10n/fr.js'
import {
  parse,
  format,
  isValid as dateFnsIsValid, // avoid overlap on pfMixinValidation::isValid()
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
    pfMixinValidation
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
      type: Number,
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
      type: String
    },
    max: {
      type: String
    },
    moments: {
      type: Array,
      default: () => []
    }
  },
  data () {
    return {
      defaultConfig: {
        allowInput: true,
        datetimeFormat: 'YYYY-MM-DD HH:mm:ss',
        time_24hr: true
      },
      initialValue: undefined,
      focus: false
    }
  },
  computed: {
    inputValue: {
      get () {
        return this.value
      },
      set (newValue) {
        const datetimeFormat = this.combinedConfig.datetimeFormat
        const value = (newValue === null) ? datetimeFormat.replace(/[a-z]/gi, '0') : newValue
        this.$emit('input', value)
      }
    },
    combinedConfig () {
      const minMaxConfig = {
        minDate: (this.min === '0000-00-00 00:00:00') ? new Date(-8640000000000000) : this.min,
        maxDate: (this.max === '0000-00-00 00:00:00') ? new Date(8640000000000000) : this.max
      }
      let config = { ...this.defaultConfig, ...minMaxConfig, ...this.config }
      if ('datetimeFormat' in config) {
        config.datetimeFormat = this.convertFormat(config.datetimeFormat)
        if (/[HhGiSsK]+/.test(config.datetimeFormat)) {
          config.enableTime = true
          config.enableSeconds = true
        } else {
          config.enableTime = false
          config.enableSeconds = false
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
      return config
    },
    locale () {
      return this.$i18n.locale
    }
  },
  methods: {
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
    toggle (event) {
      let picker = this.$refs.input.$el
      picker.focus()
    },
    reset (event) {
      this.inputValue = this.initialValue
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
      const datetimeFormat = this.config.datetimeFormat || this.defaultConfig.datetimeFormat
      const base = (event.actionKey || event.metaKey) ? parse(this.inputValue, datetimeFormat) || new Date() : new Date()
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
      let datetimeFormat = this.combinedConfig.datetimeFormat
      if ('input' in this.$refs && 'dp' in this.$refs.input) {
        return !(/[MQDdEeWwYgX]+/.test(datetimeFormat))
      }
      return false
    }
  },
  created () {
    // dereference inputValue and assign initialValue
    const datetimeFormat = this.combinedConfig.datetimeFormat
    if (this.inputValue instanceof Date) {
      // instanceof Date, convert to String
      this.inputValue = format(this.inputValue, datetimeFormat)
    }
    if (this.inputValue && this.inputValue !== datetimeFormat.replace(/[a-z]/gi, '0')) {
      // non-zero value, store for reset
      this.initialValue = format(this.inputValue, datetimeFormat)
    }
    // normalize (floor) min/max
    if (this.min) {
      this.min = parse(format((this.min instanceof Date && dateFnsIsValid(this.min) ? this.min : parse(this.min)), datetimeFormat))
    }
    if (this.max) {
      this.max = parse(format((this.max instanceof Date && dateFnsIsValid(this.max) ? this.max : parse(this.max)), datetimeFormat))
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
      background-color: transparent;
      border-right: 2px solid $white;
      padding: .375rem .75rem;
      font-size: .9rem;
      font-weight: 400;
      line-height: 1.5;
      color: #4c555a;
      font-family: inherit;
      flex: 1;
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
