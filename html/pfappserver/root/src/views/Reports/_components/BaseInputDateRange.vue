<template>
  <b-container id="BaseInputDateRange" class="px-0" fluid>
    <b-form inline>
      <b-btn variant="link" id="periods" :disabled="disabled">
        <icon name="stopwatch" />
      </b-btn>
      <b-btn v-if="hasDates"
        variant="link" @click="previousRange" v-b-tooltip.hover.bottom.d300 :title="$i18n.t('Previous date range')">
          <icon name="chevron-left" />
      </b-btn>
      <b-popover :show.sync="showPeriod"
        class="popover-full" target="periods" triggers="click focus blur" placement="bottomright" container="BaseInputDateRange">
        <b-form-row class="align-items-center">
          <div class="mx-1">{{ $t('Previous') }}</div>
            <b-button-group vrel="periodButtonGroup">
              <b-button v-for="period in periods" :key="period.text"
                variant="light" @click="setRangeByPeriod(period.value)" v-b-tooltip.hover.bottom.d300 :title="period.title">{{ period.text }}</b-button>
            </b-button-group>
        </b-form-row>
      </b-popover>
      <base-input-group-date-time v-model="startDate"
        :placeholder="$i18n.t('Start')" :disabled="disabled" :min="minStartDate" :max="maxStartDate" class="mr-1" defer />
      <base-input-group-date-time v-model="endDate"
        :placeholder="$i18n.t('End')" :disabled="disabled" :min="minEndDate" :max="maxEndDate" defer />
      <b-btn v-if="hasDates"
        variant="link" @click="nextRange" v-b-tooltip.hover.bottom.d300 :title="$i18n.t('Next date range')">
          <icon name="chevron-right" />
      </b-btn>
      <b-btn variant="link" :disabled="disabled || !hasDates || hasDateLimit" @click="clearRange">
        <icon name="trash-alt" />
      </b-btn>
    </b-form>
  </b-container>
</template>

<script>
import {
  BaseInputGroupDateTime
} from '@/components/new/'
const components = {
  BaseInputGroupDateTime
}

const props = {
  disabled: {
    type: Boolean
  },
  value: {
    type: Object,
    default: () => ({ start_date: undefined, end_date: undefined, date_limit: undefined })
  }
}

import { computed, customRef, nextTick, ref, toRefs } from '@vue/composition-api'
import { format, parse, addSeconds, subSeconds, differenceInSeconds } from 'date-fns'
import i18n from '@/utils/locale'
import { duration2seconds } from '@/views/Configuration/accessDurations/config'

const setup = (props, context) => {

  const {
    value
  } = toRefs(props)

  const { emit } = context

  const startDate = customRef((track, trigger) => ({
    get() {
      track()
      return value.value.start_date
    },
    set(start_date) {
      // only emit valid format
      if (start_date.replace(/[0-9]/g, '0') === '0000-00-00 00:00:00')
        emit('input', { ...value.value, start_date })
      else
        emit('input', { ...value.value, start_date: null })
      trigger()
    }
  }))
  const minStartDate = computed(() => {
    const { date_limit } = value.value
    if (date_limit) {
      const date = parse(endDate.value, 'YYYY-MM-DD HH:mm:ss')
      const seconds = duration2seconds(date_limit)
      const min = subSeconds(date, seconds)
      return format(min, 'YYYY-MM-DD HH:mm:ss')
    }
    return '0000-00-00 00:00:00'
  })
  const maxStartDate = computed(() => {
    if (!endDate.value || endDate.value.replace(/[0-9]/g, '0') === '0000-00-00 00:00:00')
      return endDate.value
    return '9999-12-12 23:59:59'
  })

  const endDate = customRef((track, trigger) => ({
    get() {
      track()
      return value.value.end_date
    },
    set(end_date) {
      // only emit valid format
      if (end_date.replace(/[0-9]/g, '0') === '0000-00-00 00:00:00')
        emit('input', { ...value.value, end_date })
      else
        emit('input', { ...value.value, end_date: null })
      trigger()
    }
  }))
  const minEndDate = computed(() => {
    if (!startDate.value || startDate.value.replace(/[0-9]/g, '0') === '0000-00-00 00:00:00')
      return startDate.value
    return '0000-00-00 00:00:00'
  })
  const maxEndDate = computed(() => {
    const { date_limit } = value.value
    if (date_limit) {
      const date = parse(startDate.value, 'YYYY-MM-DD HH:mm:ss')
      const seconds = duration2seconds(date_limit)
      const max = addSeconds(date, seconds)
      return format(max, 'YYYY-MM-DD HH:mm:ss')
    }
    return '9999-12-12 23:59:59'
  })

  const showPeriod = ref(false)
  const periods = computed(() => {
    const { date_limit } = value.value
    return [
      { title: i18n.t('30 minutes'), text: '30m', value: 60 * 30 },
      { title: i18n.t('1 hour'),     text: '1h',  value: 60 * 60 },
      { title: i18n.t('6 hours'),    text: '6h',  value: 60 * 60 * 6 },
      { title: i18n.t('12 hours'),   text: '12h', value: 60 * 60 * 12 },
      { title: i18n.t('1 day'),      text: '1D',  value: 60 * 60 * 24 },
      { title: i18n.t('1 week'),     text: '1W',  value: 60 * 60 * 24 * 7},
      { title: i18n.t('2 weeks'),    text: '2W',  value: 60 * 60 * 24 * 14 },
      { title: i18n.t('1 month'),    text: '1M',  value: 60 * 60 * 24 * 31 },
      { title: i18n.t('2 months'),   text: '2M',  value: 60 * 60 * 24 * 31 * 2 },
      { title: i18n.t('6 months'),   text: '6M',  value: 60 * 60 * 24 * 31 * 6 } ,
      { title: i18n.t('1 year'),     text: '1Y',  value: 60 * 60 * 24 * 365 }
    ].filter(({ value }) => {
      return !date_limit || value < duration2seconds(date_limit)
    })
  })

  const setRangeByPeriod = period => {
    showPeriod.value = false
    emit('input', {
      start_date: format(subSeconds(new Date(), period), 'YYYY-MM-DD HH:mm:ss'),
      end_date: format(new Date(), 'YYYY-MM-DD HH:mm:ss')
    })
   }

  const clearRange = () => {
    emit('input', {
      start_date: undefined,
      end_date: undefined
    })
  }

  const hasDates = computed(() => {
    const { start_date, end_date } = value.value
    return start_date && start_date !== '0000-00-00 00:00:00' && end_date
  })

  const hasDateLimit = computed(() => {
    const { date_limit } = value.value
    return !!date_limit
  })

  const previousRange = () => {
    const start = parse(startDate.value, 'YYYY-MM-DD HH:mm:ss')
    const end = parse(endDate.value, 'YYYY-MM-DD HH:mm:ss')
    const diff = differenceInSeconds(end, start)
    endDate.value = startDate.value
    nextTick(() => {
      startDate.value = format(subSeconds(start, diff), 'YYYY-MM-DD HH:mm:ss')
    })
  }

  const nextRange = () => {
    const start = parse(startDate.value, 'YYYY-MM-DD HH:mm:ss')
    const end = parse(endDate.value, 'YYYY-MM-DD HH:mm:ss')
    const diff = differenceInSeconds(end, start)
    startDate.value = endDate.value
    nextTick(() => {
      endDate.value = format(addSeconds(end, diff), 'YYYY-MM-DD HH:mm:ss')
    })
  }

  return {
    startDate,
    minStartDate,
    maxStartDate,
    endDate,
    minEndDate,
    maxEndDate,
    showPeriod,
    periods,
    setRangeByPeriod,
    clearRange,
    hasDates,
    hasDateLimit,
    previousRange,
    nextRange
  }
}

// @vue/component
export default {
  name: 'base-input-date-range',
  components,
  props,
  setup
}
</script>

<style>
/**
 * Don't limit the size of the popover
 */
#BaseInputDateRange .popover {
  max-width: none;
}

/**
 * Add btn-primary color(s) on hover
 */
.btn-group[rel=periodButtonGroup] button:hover {
  border-color: $input-btn-hover-bg-color;
  background-color: $input-btn-hover-bg-color;
  color: $input-btn-hover-text-color;
}
</style>