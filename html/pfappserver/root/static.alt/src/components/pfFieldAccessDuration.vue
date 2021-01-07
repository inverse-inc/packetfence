<template>
  <b-form-row class="pf-field-access-duration mx-0 mb-1 px-0" align-v="center">
    <b-col v-if="$slots.prepend" cols="1" align-self="start" class="text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col cols="1" align-self="start">

      <pf-form-input ref="interval"
        :form-store-name="formStoreName" :form-namespace="`${formNamespace}.interval`"
        :placeholder="'#'"
        :disabled="disabled"
        class="mr-1"
      />

    </b-col>
    <b-col cols="2" align-self="start">

      <pf-form-chosen ref="unit"
        :form-store-name="formStoreName" :form-namespace="`${formNamespace}.unit`"
        :placeholder="$t('Choose')"
        :options="intervals"
        :disabled="disabled || intervals.length === 0"
        :clearOnSelect="false"
        :allowEmpty="false"
        label="text"
        track-by="value"
        class="mr-1"
        collapse-object
      />

    </b-col>
    <b-col cols="1" align-self="start" class="text-center">

      <pf-form-range-triple ref="base"
        :form-store-name="formStoreName" :form-namespace="`${formNamespace}.base`"
        :values="{ left: null, middle: 'F', right: 'R' }"
        :icons="{ left: 'times', middle: 'step-backward', right: 'fast-backward' }"
        :colors="{ left: null, middle: 'var(--primary)', right: 'var(--success)' }"
        :tooltips="{
          left: $i18n.t('Absolute'),
          middle: $i18n.t('Relative to the beginning of the day'),
          right: $i18n.t('Relative to the beginning of the period')
        }"
        :disabled="disabled"
        class="mr-1"
        width="80"
      />

    </b-col>
    <b-col cols="1" align-self="start">

      <pf-form-input ref="extendedInterval" v-if="localBase"
        :form-store-name="formStoreName" :form-namespace="`${formNamespace}.extendedInterval`"
        :placeholder="'#'"
        :disabled="disabled"
        class="mr-1"
      />

    </b-col>
    <b-col cols="2" align-self="start">

      <pf-form-chosen ref="extendedUnit" v-if="localBase"
        :form-store-name="formStoreName" :form-namespace="`${formNamespace}.extendedUnit`"
        :placeholder="$t('Choose')"
        :options="intervals"
        :disabled="disabled || intervals.length === 0"
        :clearOnSelect="false"
        :allowEmpty="false"
        label="text"
        track-by="value"
        class="mr-1"
        collapse-object
      />

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
import pfMixinForm from '@/components/pfMixinForm'
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
  mixins: [
    pfMixinForm
  ],
  props: {
    drag: {
      type: Boolean
    },
    disabled: {
      type: Boolean,
      default: false
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
    inputValue: { // new
      get () {
        return { ...this.default, ...this.formStoreValue } // use FormStore
      },
      set (newValue = null) {
        this.formStoreValue = newValue // use FormStore
      }
    },
    localInterval () {
      return this.inputValue.interval
    },
    localUnit () {
      return this.inputValue.unit
    },
    localBase () {
      return this.inputValue.base
    },
    localExtendedInterval () {
      return this.inputValue.extendedInterval
    },
    localExtendedUnit () {
      return this.inputValue.extendedUnit
    },
    example () {
      if (this.formStoreState.$invalid) return '0000-00-00 00:00:00'
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
  created () {
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
