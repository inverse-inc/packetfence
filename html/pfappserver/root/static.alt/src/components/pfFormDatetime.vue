<!--
 * Component to pick datetime.
 *
 * Optional Properties:
 *    v-model: reactive property getter/setter
 *    value: default value
 *    label: form-group label
 *    placeholder: input placeholder
 *    prependText: input-group prepend slot
 *    config: extend/overload pc-bootstrap4-datetimepicker options
 *      See: http://eonasdan.github.io/bootstrap-datetimepicker/Options/
 *    disabled: (Boolean) true/false to disable/enable input
 *    min: (Date) minimum datetime string
 *    max: (Date) maximum datetime String
 *    moments: button array of +/- seconds from now (see: https://date-fns.org/v1.29.0/docs/addSeconds)
 *      example :moments="['-1 hours', '1 hours', '1 days', '1 weeks', '1 months', '1 quarters', '1 years']"
 -->
 <template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
    class="pf-form-datetime" :class="{ 'mb-0': !columnLabel, 'is-focus': focus}">
    <b-input-group class="pf-form-datetime-input-group">
      <b-input-group-prepend v-if="prependText">
        <div class="input-group-text">
          {{ prependText }}
        </div>
      </b-input-group-prepend>
      <date-picker
        v-model="inputValue"
        v-bind="$attrs"
        ref="input"
        :config="datetimeConfig"
        :state="isValid()"
        @input.native="validate()"
        @keyup.native="onChange($event)"
        @change.native="onChange($event)"
        @focus.native="focus = true"
        @blur.native="focus = false"
      ></date-picker>
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
import datePicker from 'vue-bootstrap-datetimepicker'
import 'pc-bootstrap4-datetimepicker/build/css/bootstrap-datetimepicker.css'
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
    'date-picker': datePicker
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
      type: Object
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
        debug: false,
        format: 'YYYY-MM-DD HH:mm:ss',
        stepping: 1,
        collapse: true,
        icons: {
          time: 'icon-datetime icon-datetime-time',
          date: 'icon-datetime icon-datetime-date',
          up: 'icon-datetime icon-datetime-up',
          down: 'icon-datetime icon-datetime-down',
          previous: 'icon-datetime icon-datetime-previous',
          next: 'icon-datetime icon-datetime-next',
          today: 'icon-datetime icon-datetime-today',
          clear: 'icon-datetime icon-datetime-clear',
          close: 'icon-datetime icon-datetime-close'
        },
        sideBySide: false,
        showTodayButton: true,
        showClear: true,
        showClose: true,
        toolbarPlacement: 'top',
        tooltips: {
          today: this.$i18n.t('Go to today'),
          clear: this.$i18n.t('Clear selection'),
          close: this.$i18n.t('Close the picker'),
          selectMonth: this.$i18n.t('Select Month'),
          prevMonth: this.$i18n.t('Previous Month'),
          nextMonth: this.$i18n.t('Next Month'),
          selectYear: this.$i18n.t('Select Year'),
          prevYear: this.$i18n.t('Previous Year'),
          nextYear: this.$i18n.t('Next Year'),
          selectDecade: this.$i18n.t('Select Decade'),
          prevDecade: this.$i18n.t('Previous Decade'),
          nextDecade: this.$i18n.t('Next Decade'),
          prevCentury: this.$i18n.t('Previous Century'),
          nextCentury: this.$i18n.t('Next Century'),
          incrementHour: this.$i18n.t('Increment Hour'),
          pickHour: this.$i18n.t('Pick Hour'),
          decrementHour: this.$i18n.t('Decrement Hour'),
          incrementMinute: this.$i18n.t('Increment Minute'),
          pickMinute: this.$i18n.t('Pick Minute'),
          decrementMinute: this.$i18n.t('Decrement Minute'),
          incrementSecond: this.$i18n.t('Increment Second'),
          pickSecond: this.$i18n.t('Pick Second'),
          decrementSecond: this.$i18n.t('Decrement Second')
        },
        useCurrent: false
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
        const dateFormat = Object.assign(this.defaultConfig, this.config).format
        const value = (newValue === null) ? dateFormat.replace(/[a-z]/gi, '0') : newValue
        this.$emit('input', value)
      }
    },
    datetimeConfig () {
      const minMaxConfig = {
        minDate: (this.min === '0000-00-00 00:00:00') ? new Date(-8640000000000000) : this.min,
        maxDate: (this.max === '0000-00-00 00:00:00') ? new Date(8640000000000000) : this.max
      }
      return Object.assign(this.defaultConfig, minMaxConfig, this.config)
    }
  },
  methods: {
    toggle (event) {
      let picker = this.$refs.input.dp
      picker.toggle()
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
      const dateFormat = this.datetimeConfig.format
      const base = (event.ctrlKey || event.metaKey) ? parse(this.inputValue, dateFormat) || new Date() : new Date()
      if (validMomentKeys.includes(key)) {
        switch (key) {
          case 'years':
            this.inputValue = format(addYears(base, amount), dateFormat)
            break
          case 'quarters':
            this.inputValue = format(addQuarters(base, amount), dateFormat)
            break
          case 'months':
            this.inputValue = format(addMonths(base, amount), dateFormat)
            break
          case 'weeks':
            this.inputValue = format(addWeeks(base, amount), dateFormat)
            break
          case 'days':
            this.inputValue = format(addDays(base, amount), dateFormat)
            break
          case 'hours':
            this.inputValue = format(addHours(base, amount), dateFormat)
            break
          case 'minutes':
            this.inputValue = format(addMinutes(base, amount), dateFormat)
            break
          case 'seconds':
            this.inputValue = format(addSeconds(base, amount), dateFormat)
            break
          case 'milliseconds':
            this.inputValue = format(addMilliseconds(base, amount), dateFormat)
            break
          default:
            this.inputValue = format(base, dateFormat)
        }
      }
    },
    formatIsTimeOnly () {
      let format = this.defaultConfig.format
      if ('input' in this.$refs && 'dp' in this.$refs.input) {
        return !(/[MQDdEeWwYgX]+/.test(format))
      }
      return false
    }
  },
  watch: {
    min (a, b) {
      const dateFormat = Object.assign(this.defaultConfig, this.config).format
      a = parse(format((a instanceof Date && dateFnsIsValid(a) ? a : parse(a)), dateFormat))
      let picker = this.$refs.input.dp
      picker.minDate(a)
    },
    max (a, b) {
      const dateFormat = Object.assign(this.defaultConfig, this.config).format
      a = parse(format((a instanceof Date && dateFnsIsValid(a) ? a : parse(a)), dateFormat))
      let picker = this.$refs.input.dp
      picker.maxDate(a)
    }
  },
  created () {
    // dereference inputValue and assign initialValue
    const dateFormat = Object.assign(this.defaultConfig, this.config).format
    if (this.inputValue instanceof Date) {
      // instanceof Date, convert to String
      this.inputValue = format(this.inputValue, dateFormat)
    }
    if (this.inputValue && this.inputValue !== dateFormat.replace(/[a-z]/gi, '0')) {
      // non-zero value, store for reset
      this.initialValue = format(this.inputValue, dateFormat)
    }
    // normalize (floor) min/max
    if (this.min) {
      this.min = parse(format((this.min instanceof Date && dateFnsIsValid(this.min) ? this.min : parse(this.min)), dateFormat))
    }
    if (this.max) {
      this.max = parse(format((this.max instanceof Date && dateFnsIsValid(this.max) ? this.max : parse(this.max)), dateFormat))
    }
  }
}
</script>

<style lang="scss">
@import "../../node_modules/bootstrap/scss/functions";
@import "../../node_modules/bootstrap/scss/mixins/border-radius";
@import "../../node_modules/bootstrap/scss/mixins/transition";
@import "../styles/variables";

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
  .bootstrap-datetimepicker-widget {
    border: $dropdown-border-width solid $dropdown-border-color;
  }
  &.is-focus .pf-form-datetime-input-group,
  &.is-focus .bootstrap-datetimepicker-widget {
    border: 1px solid $input-focus-border-color;
    box-shadow: 0 0 0 $input-focus-width rgba($input-focus-border-color, .25);
  }
  &.is-invalid .pf-form-datetime-input-group,
  &.is-invalid .bootstrap-datetimepicker-widget {
    border: 1px solid $form-feedback-invalid-color;
    box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-invalid-color, .25);
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
 * vue-bootstrap-datetimepicker only supports fontawesome icons,
 * define base64 encoded icon content and style dirrectly.
 */
.icon-datetime {
  opacity: 0.25;
  transition: all 300ms ease;
}
.icon-datetime:hover {
  opacity: 1;
}
.icon-datetime-time {
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDUxMiA1MTIiPjxwYXRoIGQ9Ik0yNTYgOEMxMTkgOCA4IDExOSA4IDI1NnMxMTEgMjQ4IDI0OCAyNDggMjQ4LTExMSAyNDgtMjQ4UzM5MyA4IDI1NiA4em0wIDQ0OGMtMTEwLjUgMC0yMDAtODkuNS0yMDAtMjAwUzE0NS41IDU2IDI1NiA1NnMyMDAgODkuNSAyMDAgMjAwLTg5LjUgMjAwLTIwMCAyMDB6bTYxLjgtMTA0LjRsLTg0LjktNjEuN2MtMy4xLTIuMy00LjktNS45LTQuOS05LjdWMTE2YzAtNi42IDUuNC0xMiAxMi0xMmgzMmM2LjYgMCAxMiA1LjQgMTIgMTJ2MTQxLjdsNjYuOCA0OC42YzUuNCAzLjkgNi41IDExLjQgMi42IDE2LjhMMzM0LjYgMzQ5Yy0zLjkgNS4zLTExLjQgNi41LTE2LjggMi42eiIgY2xhc3M9IiI+PC9wYXRoPjwvc3ZnPg==);
  width: 24px !important;
  height: 24px !important;
}
.icon-datetime-date {
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDQ0OCA1MTIiPjxwYXRoIGZpbGw9ImN1cnJlbnRDb2xvciIgZD0iTTE0OCAyODhoLTQwYy02LjYgMC0xMi01LjQtMTItMTJ2LTQwYzAtNi42IDUuNC0xMiAxMi0xMmg0MGM2LjYgMCAxMiA1LjQgMTIgMTJ2NDBjMCA2LjYtNS40IDEyLTEyIDEyem0xMDgtMTJ2LTQwYzAtNi42LTUuNC0xMi0xMi0xMmgtNDBjLTYuNiAwLTEyIDUuNC0xMiAxMnY0MGMwIDYuNiA1LjQgMTIgMTIgMTJoNDBjNi42IDAgMTItNS40IDEyLTEyem05NiAwdi00MGMwLTYuNi01LjQtMTItMTItMTJoLTQwYy02LjYgMC0xMiA1LjQtMTIgMTJ2NDBjMCA2LjYgNS40IDEyIDEyIDEyaDQwYzYuNiAwIDEyLTUuNCAxMi0xMnptLTk2IDk2di00MGMwLTYuNi01LjQtMTItMTItMTJoLTQwYy02LjYgMC0xMiA1LjQtMTIgMTJ2NDBjMCA2LjYgNS40IDEyIDEyIDEyaDQwYzYuNiAwIDEyLTUuNCAxMi0xMnptLTk2IDB2LTQwYzAtNi42LTUuNC0xMi0xMi0xMmgtNDBjLTYuNiAwLTEyIDUuNC0xMiAxMnY0MGMwIDYuNiA1LjQgMTIgMTIgMTJoNDBjNi42IDAgMTItNS40IDEyLTEyem0xOTIgMHYtNDBjMC02LjYtNS40LTEyLTEyLTEyaC00MGMtNi42IDAtMTIgNS40LTEyIDEydjQwYzAgNi42IDUuNCAxMiAxMiAxMmg0MGM2LjYgMCAxMi01LjQgMTItMTJ6bTk2LTI2MHYzNTJjMCAyNi41LTIxLjUgNDgtNDggNDhINDhjLTI2LjUgMC00OC0yMS41LTQ4LTQ4VjExMmMwLTI2LjUgMjEuNS00OCA0OC00OGg0OFYxMmMwLTYuNiA1LjQtMTIgMTItMTJoNDBjNi42IDAgMTIgNS40IDEyIDEydjUyaDEyOFYxMmMwLTYuNiA1LjQtMTIgMTItMTJoNDBjNi42IDAgMTIgNS40IDEyIDEydjUyaDQ4YzI2LjUgMCA0OCAyMS41IDQ4IDQ4em0tNDggMzQ2VjE2MEg0OHYyOThjMCAzLjMgMi43IDYgNiA2aDM0MGMzLjMgMCA2LTIuNyA2LTZ6Ij48L3BhdGg+PC9zdmc+);
  width: 24px !important;
  height: 24px !important;
}
.icon-datetime-up {
  content:url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDQ0OCA1MTIiPjxwYXRoIGZpbGw9ImN1cnJlbnRDb2xvciIgZD0iTTI0MC45NzEgMTMwLjUyNGwxOTQuMzQzIDE5NC4zNDNjOS4zNzMgOS4zNzMgOS4zNzMgMjQuNTY5IDAgMzMuOTQxbC0yMi42NjcgMjIuNjY3Yy05LjM1NyA5LjM1Ny0yNC41MjIgOS4zNzUtMzMuOTAxLjA0TDIyNCAyMjcuNDk1IDY5LjI1NSAzODEuNTE2Yy05LjM3OSA5LjMzNS0yNC41NDQgOS4zMTctMzMuOTAxLS4wNGwtMjIuNjY3LTIyLjY2N2MtOS4zNzMtOS4zNzMtOS4zNzMtMjQuNTY5IDAtMzMuOTQxTDIwNy4wMyAxMzAuNTI1YzkuMzcyLTkuMzczIDI0LjU2OC05LjM3MyAzMy45NDEtLjAwMXoiPjwvcGF0aD48L3N2Zz4=);
  padding: 15px;
}
.icon-datetime-down {
  content:url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDQ0OCA1MTIiPjxwYXRoIGZpbGw9ImN1cnJlbnRDb2xvciIgZD0iTTIwNy4wMjkgMzgxLjQ3NkwxMi42ODYgMTg3LjEzMmMtOS4zNzMtOS4zNzMtOS4zNzMtMjQuNTY5IDAtMzMuOTQxbDIyLjY2Ny0yMi42NjdjOS4zNTctOS4zNTcgMjQuNTIyLTkuMzc1IDMzLjkwMS0uMDRMMjI0IDI4NC41MDVsMTU0Ljc0NS0xNTQuMDIxYzkuMzc5LTkuMzM1IDI0LjU0NC05LjMxNyAzMy45MDEuMDRsMjIuNjY3IDIyLjY2N2M5LjM3MyA5LjM3MyA5LjM3MyAyNC41NjkgMCAzMy45NDFMMjQwLjk3MSAzODEuNDc2Yy05LjM3MyA5LjM3Mi0yNC41NjkgOS4zNzItMzMuOTQyIDB6Ij48L3BhdGg+PC9zdmc+);
  padding: 15px;
}
.icon-datetime-previous {
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDMyMCA1MTIiPjxwYXRoIGZpbGw9ImN1cnJlbnRDb2xvciIgZD0iTTM0LjUyIDIzOS4wM0wyMjguODcgNDQuNjljOS4zNy05LjM3IDI0LjU3LTkuMzcgMzMuOTQgMGwyMi42NyAyMi42N2M5LjM2IDkuMzYgOS4zNyAyNC41Mi4wNCAzMy45TDEzMS40OSAyNTZsMTU0LjAyIDE1NC43NWM5LjM0IDkuMzggOS4zMiAyNC41NC0uMDQgMzMuOWwtMjIuNjcgMjIuNjdjLTkuMzcgOS4zNy0yNC41NyA5LjM3LTMzLjk0IDBMMzQuNTIgMjcyLjk3Yy05LjM3LTkuMzctOS4zNy0yNC41NyAwLTMzLjk0eiI+PC9wYXRoPjwvc3ZnPg==);
  width: 15px;
  height: 24px;
}
.icon-datetime-next {
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDMyMCA1MTIiPjxwYXRoIGQ9Ik0yODUuNDc2IDI3Mi45NzFMOTEuMTMyIDQ2Ny4zMTRjLTkuMzczIDkuMzczLTI0LjU2OSA5LjM3My0zMy45NDEgMGwtMjIuNjY3LTIyLjY2N2MtOS4zNTctOS4zNTctOS4zNzUtMjQuNTIyLS4wNC0zMy45MDFMMTg4LjUwNSAyNTYgMzQuNDg0IDEwMS4yNTVjLTkuMzM1LTkuMzc5LTkuMzE3LTI0LjU0NC4wNC0zMy45MDFsMjIuNjY3LTIyLjY2N2M5LjM3My05LjM3MyAyNC41NjktOS4zNzMgMzMuOTQxIDBMMjg1LjQ3NSAyMzkuMDNjOS4zNzMgOS4zNzIgOS4zNzMgMjQuNTY4LjAwMSAzMy45NDF6Ij48L3BhdGg+PC9zdmc+);
  width: 15px;
  height: 24px;
}
.icon-datetime-today {
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDQ0OCA1MTIiPjxwYXRoIGQ9Ik00MDAgNjRoLTQ4VjEyYzAtNi42MjctNS4zNzMtMTItMTItMTJoLTQwYy02LjYyNyAwLTEyIDUuMzczLTEyIDEydjUySDE2MFYxMmMwLTYuNjI3LTUuMzczLTEyLTEyLTEyaC00MGMtNi42MjcgMC0xMiA1LjM3My0xMiAxMnY1Mkg0OEMyMS40OSA2NCAwIDg1LjQ5IDAgMTEydjM1MmMwIDI2LjUxIDIxLjQ5IDQ4IDQ4IDQ4aDM1MmMyNi41MSAwIDQ4LTIxLjQ5IDQ4LTQ4VjExMmMwLTI2LjUxLTIxLjQ5LTQ4LTQ4LTQ4em0tNiA0MDBINTRhNiA2IDAgMCAxLTYtNlYxNjBoMzUydjI5OGE2IDYgMCAwIDEtNiA2em0tNTIuODQ5LTIwMC42NUwxOTguODQyIDQwNC41MTljLTQuNzA1IDQuNjY3LTEyLjMwMyA0LjYzNy0xNi45NzEtLjA2OGwtNzUuMDkxLTc1LjY5OWMtNC42NjctNC43MDUtNC42MzctMTIuMzAzLjA2OC0xNi45NzFsMjIuNzE5LTIyLjUzNmM0LjcwNS00LjY2NyAxMi4zMDMtNC42MzcgMTYuOTcuMDY5bDQ0LjEwNCA0NC40NjEgMTExLjA3Mi0xMTAuMTgxYzQuNzA1LTQuNjY3IDEyLjMwMy00LjYzNyAxNi45NzEuMDY4bDIyLjUzNiAyMi43MThjNC42NjcgNC43MDUgNC42MzYgMTIuMzAzLS4wNjkgMTYuOTd6Ij48L3BhdGg+PC9zdmc+);
  width: 24px !important;
  height: 24px !important;
}
.icon-datetime-clear {
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDY0MCA1MTIiPjxwYXRoIGZpbGw9ImN1cnJlbnRDb2xvciIgZD0iTTU3NiA2NEgyMDUuMjZBNjMuOTcgNjMuOTcgMCAwIDAgMTYwIDgyLjc1TDkuMzcgMjMzLjM3Yy0xMi41IDEyLjUtMTIuNSAzMi43NiAwIDQ1LjI1TDE2MCA0MjkuMjVjMTIgMTIgMjguMjggMTguNzUgNDUuMjUgMTguNzVINTc2YzM1LjM1IDAgNjQtMjguNjUgNjQtNjRWMTI4YzAtMzUuMzUtMjguNjUtNjQtNjQtNjR6bS04NC42OSAyNTQuMDZjNi4yNSA2LjI1IDYuMjUgMTYuMzggMCAyMi42M2wtMjIuNjIgMjIuNjJjLTYuMjUgNi4yNS0xNi4zOCA2LjI1LTIyLjYzIDBMMzg0IDMwMS4yNWwtNjIuMDYgNjIuMDZjLTYuMjUgNi4yNS0xNi4zOCA2LjI1LTIyLjYzIDBsLTIyLjYyLTIyLjYyYy02LjI1LTYuMjUtNi4yNS0xNi4zOCAwLTIyLjYzTDMzOC43NSAyNTZsLTYyLjA2LTYyLjA2Yy02LjI1LTYuMjUtNi4yNS0xNi4zOCAwLTIyLjYzbDIyLjYyLTIyLjYyYzYuMjUtNi4yNSAxNi4zOC02LjI1IDIyLjYzIDBMMzg0IDIxMC43NWw2Mi4wNi02Mi4wNmM2LjI1LTYuMjUgMTYuMzgtNi4yNSAyMi42MyAwbDIyLjYyIDIyLjYyYzYuMjUgNi4yNSA2LjI1IDE2LjM4IDAgMjIuNjNMNDI5LjI1IDI1Nmw2Mi4wNiA2Mi4wNnoiPjwvcGF0aD48L3N2Zz4=);
  width: 24px !important;
  height: 24px !important;
}
.icon-datetime-close {
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDM1MiA1MTIiPjxwYXRoIGQ9Ik0yNDIuNzIgMjU2bDEwMC4wNy0xMDAuMDdjMTIuMjgtMTIuMjggMTIuMjgtMzIuMTkgMC00NC40OGwtMjIuMjQtMjIuMjRjLTEyLjI4LTEyLjI4LTMyLjE5LTEyLjI4LTQ0LjQ4IDBMMTc2IDE4OS4yOCA3NS45MyA4OS4yMWMtMTIuMjgtMTIuMjgtMzIuMTktMTIuMjgtNDQuNDggMEw5LjIxIDExMS40NWMtMTIuMjggMTIuMjgtMTIuMjggMzIuMTkgMCA0NC40OEwxMDkuMjggMjU2IDkuMjEgMzU2LjA3Yy0xMi4yOCAxMi4yOC0xMi4yOCAzMi4xOSAwIDQ0LjQ4bDIyLjI0IDIyLjI0YzEyLjI4IDEyLjI4IDMyLjIgMTIuMjggNDQuNDggMEwxNzYgMzIyLjcybDEwMC4wNyAxMDAuMDdjMTIuMjggMTIuMjggMzIuMiAxMi4yOCA0NC40OCAwbDIyLjI0LTIyLjI0YzEyLjI4LTEyLjI4IDEyLjI4LTMyLjE5IDAtNDQuNDhMMjQyLjcyIDI1NnoiIGNsYXNzPSIiPjwvcGF0aD48L3N2Zz4=);
  width: 24px !important;
  height: 24px !important;
}
</style>
