<template>
  <b-form-row class="pf-field-access-duration mx-0 mb-1 px-0" align-v="center"
    v-on="forwardListeners"
  >
    <b-col v-if="$slots.prepend" cols="1" align-self="start" class="text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col cols="1" align-self="start">

      <pf-form-input
        v-model="localInterval"
        ref="localInterval"
        :placeholder="'#'"
        :vuelidate="intervalVuelidateModel"
        :invalid-feedback="intervalInvalidFeedback"
        class="mr-1"
      ></pf-form-input>

    </b-col>
    <b-col cols="2" align-self="start">

      <pf-form-chosen
        v-model="localUnit"
        ref="localUnit"
        label="text"
        track-by="value"
        :placeholder="$t('Choose')"
        :options="intervals"
        :disabled="intervals.length === 0"
        :vuelidate="unitVuelidateModel"
        :invalid-feedback="unitInvalidFeedback"
        :clearOnSelect="false"
        :allowEmpty="false"
        class="mr-1"
        collapse-object
      ></pf-form-chosen>

    </b-col>
    <b-col cols="1" align-self="start" class="text-center">

      <pf-form-range-triple
        v-model="localBase"
        ref="localBase"
        :values="{ left: null, middle: 'F', right: 'R' }"
        :icons="{ left: 'times', middle: 'step-backward', right: 'fast-backward' }"
        :colors="{ left: null, middle: 'var(--primary)', right: 'var(--success)' }"
        :tooltips="{
          left: $i18n.t('Absolute'),
          middle: $i18n.t('Relative to the beginning of the day'),
          right: $i18n.t('Relative to the beginning of the period')
        }"
        class="mr-1"
        width="80"
      ></pf-form-range-triple>

    </b-col>
    <b-col cols="1" align-self="start">

      <pf-form-input v-if="localBase"
        v-model="localExtendedInterval"
        ref="localExtendedInterval"
        :placeholder="'#'"
        :vuelidate="extendedIntervalVuelidateModel"
        :invalid-feedback="extendedIntervalInvalidFeedback"
        class="mr-1"
      ></pf-form-input>

    </b-col>
    <b-col cols="2" align-self="start">

      <pf-form-chosen v-if="localBase"
        v-model="localExtendedUnit"
        ref="localExtendedUnit"
        label="text"
        track-by="value"
        :placeholder="$t('Choose')"
        :options="intervals"
        :disabled="intervals.length === 0"
        :vuelidate="extendedUnitVuelidateModel"
        :invalid-feedback="extendednitInvalidFeedback"
        :clearOnSelect="false"
        :allowEmpty="false"
        class="mr-1"
        collapse-object
      ></pf-form-chosen>

    </b-col>
    <b-col cols="3" align-self="start" class="text-center col-form-label-lg">
      <code>{{ example }}</code>
    </b-col>
    <b-col v-if="$slots.append" cols="1" align-self="start" class="text-center">
      <slot name="append"></slot>
    </b-col>
  </b-form-row>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeTriple from '@/components/pfFormRangeTriple'
import {
  pfAuthenticationConditionType as authenticationConditionType,
  pfAuthenticationConditionOperators as authenticationConditionOperators,
  pfAuthenticationConditionValues as authenticationConditionValues
} from '@/globals/pfAuthenticationConditions'
import {
  required,
  integer,
  minValue
} from 'vuelidate/lib/validators'
import {
  conditional,
  and,
  not,
  or
} from '@/globals/pfValidators'
import {
  format,
  addSeconds,
  addMinutes,
  addHours,
  addDays,
  addWeeks,
  addMonths,
  addYears,
  startOfSecond,
  startOfMinute,
  startOfHour,
  startOfDay,
  startOfWeek,
  startOfMonth,
  startOfYear
} from 'date-fns'

export default {
  name: 'pf-field-access-duration',
  components: {
    pfFormChosen,
    pfFormInput,
    pfFormRangeTriple
  },
  props: {
    value: {
      type: Object,
      default: () => { return this.default }
    },
    vuelidate: {
      type: Object,
      default: () => { return {} }
    },
    drag: {
      type: Boolean
    }
  },
  data () {
    return {
      default: { interval: null, unit: null, base: null, extendedInterval: null, extendedUnit: null }, // default value
      intervals: [
        { value: 's', text: this.$i18n.t('seconds') },
        { value: 'm', text: this.$i18n.t('minutes') },
        { value: 'h', text: this.$i18n.t('hours') },
        { value: 'D', text: this.$i18n.t('days') },
        { value: 'W', text: this.$i18n.t('weeks') },
        { value: 'M', text: this.$i18n.t('months') },
        { value: 'Y', text: this.$i18n.t('years') }
      ],
      date: new Date()
    }
  },
  computed: {
    inputValue: {
      get () {
        if (!this.value || Object.keys(this.value).length === 0) {
          // set default placeholder
          this.$emit('input', JSON.parse(JSON.stringify(this.default))) // keep dereferenced
          return this.default
        }
        return this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    },
    localInterval: {
      get () {
        return (this.inputValue && 'interval' in this.inputValue) ? this.inputValue.interval : this.default.interval
      },
      set (newInterval) {
        this.$set(this, 'inputValue', { ...this.inputValue, ...{ interval: newInterval || this.default.interval } })
        this.emitValidations()
      }
    },
    localUnit: {
      get () {
        return (this.inputValue && 'unit' in this.inputValue) ? this.inputValue.unit : this.default.unit
      },
      set (newUnit) {
        this.$set(this, 'inputValue', { ...this.inputValue, ...{ unit: newUnit || this.default.unit } })
        this.emitValidations()
      }
    },
    localBase: {
      get () {
        return (this.inputValue && 'base' in this.inputValue) ? this.inputValue.base : this.default.base
      },
      set (newBase) {
        this.$set(this, 'inputValue', { ...this.inputValue, ...{ base: newBase || this.default.base } })
        this.emitValidations()
      }
    },
    localExtendedInterval: {
      get () {
        return (this.inputValue && 'extendedInterval' in this.inputValue) ? this.inputValue.extendedInterval : this.default.extendedInterval
      },
      set (newExtendedInterval) {
        this.$set(this, 'inputValue', { ...this.inputValue, ...{ extendedInterval: newExtendedInterval || this.default.extendedInterval } })
        this.emitValidations()
      }
    },
    localExtendedUnit: {
      get () {
        return (this.inputValue && 'extendedUnit' in this.inputValue) ? this.inputValue.extendedUnit : this.default.extendedUnit
      },
      set (newExtendedUnit) {
        this.$set(this, 'inputValue', { ...this.inputValue, ...{ extendedUnit: newExtendedUnit || this.default.extendedUnit } })
        this.emitValidations()
      }
    },
    intervalVuelidateModel () {
      return this.getVuelidateModel('interval')
    },
    intervalInvalidFeedback () {
      return this.getInvalidFeedback('interval')
    },
    unitVuelidateModel () {
      return this.getVuelidateModel('unit')
    },
    unitInvalidFeedback () {
      return this.getInvalidFeedback('unit')
    },
    baseVuelidateModel () {
      return this.getVuelidateModel('base')
    },
    baseInvalidFeedback () {
      return this.getInvalidFeedback('base')
    },
    extendedIntervalVuelidateModel () {
      return this.getVuelidateModel('extendedInterval')
    },
    extendedIntervalInvalidFeedback () {
      return this.getInvalidFeedback('extendedInterval')
    },
    extendedUnitVuelidateModel () {
      return this.getVuelidateModel('extendedUnit')
    },
    extendedUnitInvalidFeedback () {
      return this.getInvalidFeedback('extendedUnit')
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    },
    example () {
      if (this.vuelidate.$anyError) return '0000-00-00 00:00:00'
      let date = this.date
      switch (this.inputValue.base) {
        case 'F': // beginning of day
          date = startOfDay(date)
          break
        case 'R': // beginning of period
          switch (this.inputValue.unit) {
            case 's': date = startOfSecond(date); break
            case 'm': date = startOfMinute(date); break
            case 'h': date = startOfHour(date); break
            case 'D': date = startOfDay(date); break
            case 'W': date = startOfWeek(date); break
            case 'M': date = startOfMonth(date); break
            case 'Y': date = startOfYear(date); break
          }
          break
      }
      switch (this.inputValue.unit) {
        case 's': date = addSeconds(date, this.inputValue.interval); break
        case 'm': date = addMinutes(date, this.inputValue.interval); break
        case 'h': date = addHours(date, this.inputValue.interval); break
        case 'D': date = addDays(date, this.inputValue.interval); break
        case 'W': date = addWeeks(date, this.inputValue.interval); break
        case 'M': date = addMonths(date, this.inputValue.interval); break
        case 'Y': date = addYears(date, this.inputValue.interval); break
      }
      switch (this.inputValue.extendedUnit) {
        case 's': date = addSeconds(date, this.inputValue.extendedInterval); break
        case 'm': date = addMinutes(date, this.inputValue.extendedInterval); break
        case 'h': date = addHours(date, this.inputValue.extendedInterval); break
        case 'D': date = addDays(date, this.inputValue.extendedInterval); break
        case 'W': date = addWeeks(date, this.inputValue.extendedInterval); break
        case 'M': date = addMonths(date, this.inputValue.extendedInterval); break
        case 'Y': date = addYears(date, this.inputValue.extendedInterval); break
      }
      return format(date, 'YYYY-MM-DD HH:mm:ss')
    }
  },
  methods: {
    getVuelidateModel (key = null) {
      const { vuelidate: { [key]: model } } = this
      return model || {}
    },
    getInvalidFeedback (key = null) {
      let feedback = []
      const vuelidate = this.getVuelidateModel(key)
      if (vuelidate !== {} && key in vuelidate) {
        Object.entries(vuelidate[key].$params).forEach(([k, v]) => {
          if (vuelidate[key][k] === false) feedback.push(k.trim())
        })
      }
      return feedback.join('<br/>')
    },
    buildLocalValidations () {
      const { field } = this
      if (field) {
        const { validators } = field
        if (validators) {
          return validators
        }
      }
      return {
        interval: {
          [this.$i18n.t('Positive #\'s.')]: and(required, integer, minValue(1))
        },
        unit: {
          [this.$i18n.t('Required.')]: required
        },
        extendedInterval: {
          [this.$i18n.t('Non-zero #\'s.')]: not(and(
            conditional(!!this.localBase),
            or(
              not(integer),
              conditional(~~this.localExtendedInterval === 0)
            )
          ))
        },
        extendedUnit: {
          [this.$i18n.t('Required.')]: not(and(
            conditional(!!this.localBase),
            not(required)
          ))
        }
      }
    },
    emitValidations () {
      this.$nextTick(() => {
        this.$emit('validations', this.buildLocalValidations())
      })
    }
  },
  created () {
    this.emitValidations()
    setInterval(() => {
      this.date = new Date()
    }, 1000)
  }
}
</script>

<style lang="scss">
.pf-field-access-duration {
  .pf-form-chosen {
    .col-sm-12[role="group"] {
      padding-right: 0px;
      padding-left: 0px;
    }
  }
}
</style>
