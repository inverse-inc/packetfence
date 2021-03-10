<template>
  <b-row>
    <b-col cols="4" class="base-flex-wrap px-0">

      <base-input-number ref="intervalComponentRef"
        :namespace="`${namespace}.interval`"
      />

      <base-input-chosen-one ref="unitComponentRef"
        :namespace="`${namespace}.unit`"
        :options="unitOptions"
      />

    </b-col>
    <b-col cols="5" class="base-flex-wrap px-0">

      <base-input-toggle-base
        ref="baseComponentRef"
        :namespace="`${namespace}.base`"
      />

      <base-input-number v-if="isExtended"
        ref="extendedIntervalComponentRef"
        :namespace="`${namespace}.extendedInterval`"
      />

      <base-input-chosen-one v-if="isExtended"
        ref="extendedUnitComponentRef"
        :namespace="`${namespace}.extendedUnit`"
        :options="extendedUnitOptions"
      />

    </b-col>
    <b-col cols="3" class="px-0 align-self-center">

      <code>{{example}}</code>

    </b-col>
  </b-row>
</template>
<script>
import {
  BaseInputNumber,
  BaseInputChosenOne
} from '@/components/new'
import BaseInputToggleBase from './BaseInputToggleBase'

const components = {
  BaseInputNumber,
  BaseInputChosenOne,

  BaseInputToggleBase,
}

import { computed, onBeforeUnmount, onMounted, ref, watch } from '@vue/composition-api'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import {
  intervalsOptions ,
  composeDuration,
  serializeDuration
} from '../config'
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

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    value: inputValue,
    onChange
  } = useInputValue(metaProps, context)

  const isExtended = computed(() => inputValue.value && ['F', 'R'].includes(inputValue.value.base))

  watch(
    isExtended,
    isExtended => { // mutate `extendedInterval` and `extendedUnit` on `base` change to trigger validations
      if (isExtended)
        onChange({ ...inputValue.value, extendedInterval: null, extendedUnit: null })
      else
        onChange({ ...inputValue.value, extendedInterval: undefined, extendedUnit: undefined })
    }
  )

  // update `text` and `value` when duration is mutated,
  //  since these are composed onChange() is not needed
  watch(() => serializeDuration(inputValue.value), serialized => {
    const { text } = composeDuration(serialized) || {}
    inputValue.value = { ...inputValue.value, text, value: serialized }
  }, { immediate: true })

  // generate heartbeat `now`
  const now = ref((new Date()).getTime())
  let heartbeatInterval
  onMounted(() => {
    heartbeatInterval = setInterval(() => {
      now.value = (new Date()).getTime()
    }, 1000)
  })
  onBeforeUnmount(() => heartbeatInterval && clearInterval(heartbeatInterval))

  const example = computed(() => {
    let date = now.value
    const { base, interval, unit, extendedInterval, extendedUnit } = inputValue.value
    switch (base) {
      case 'F': // beginning of day
        date = startOfDay(date)
        break
      case 'R': // beginning of period
        switch (unit) {
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
    switch (unit) {
      case 's': date = addSeconds(date, interval); break
      case 'm': date = addMinutes(date, interval); break
      case 'h': date = addHours(date, interval); break
      case 'D': date = addDays(date, interval); break
      case 'W': date = addWeeks(date, interval); break
      case 'M': date = addMonths(date, interval); break
      case 'Y': date = addYears(date, interval); break
    }
    switch (extendedUnit) {
      case 's': date = addSeconds(date, extendedInterval); break
      case 'm': date = addMinutes(date, extendedInterval); break
      case 'h': date = addHours(date, extendedInterval); break
      case 'D': date = addDays(date, extendedInterval); break
      case 'W': date = addWeeks(date, extendedInterval); break
      case 'M': date = addMonths(date, extendedInterval); break
      case 'Y': date = addYears(date, extendedInterval); break
    }
    return format(date, 'YYYY-MM-DD HH:mm:ss')
  })

  const intervalComponentRef = ref(null)

  const unitComponentRef = ref(null)
  const unitOptions = intervalsOptions

  const baseComponentRef = ref(null)

  const extendedIntervalComponentRef = ref(null)

  const extendedUnitComponentRef = ref(null)
  const extendedUnitOptions = intervalsOptions

  return {
    intervalComponentRef,
    unitComponentRef,
    unitOptions,
    baseComponentRef,
    extendedIntervalComponentRef,
    extendedUnitComponentRef,
    extendedUnitOptions,
    example,
    isExtended
  }
}

// @vue/component
export default {
  name: 'base-access-duration',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
