<template>
  <b-container id="BaseInputDateRange" class="px-0" fluid>
    <b-form inline>
      <b-btn variant="link" id="periods" :disabled="disabled">
        <icon name="stopwatch"></icon>
      </b-btn>
      <b-popover :show.sync="showPeriod"
        class="popover-full" target="periods" triggers="click focus blur" placement="bottomright" container="BaseInputDateRange">
        <b-form-row class="align-items-center">
          <div class="mx-1">{{ $t('Previous') }}</div>
            <b-button-group vrel="periodButtonGroup">
              <b-button variant="light" @click="setRangeByPeriod(60 * 30)" v-b-tooltip.hover.bottom.d300 :title="$t('30 minutes')">30m</b-button>
              <b-button variant="light" @click="setRangeByPeriod(60 * 60)" v-b-tooltip.hover.bottom.d300 :title="$t('1 hour')">1h</b-button>
              <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 6)" v-b-tooltip.hover.bottom.d300 :title="$t('6 hours')">6h</b-button>
              <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 12)" v-b-tooltip.hover.bottom.d300 :title="$t('12 hours')">12h</b-button>
              <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24)" v-b-tooltip.hover.bottom.d300 :title="$t('1 day')">1D</b-button>
              <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24 * 7)" v-b-tooltip.hover.bottom.d300 :title="$t('1 week')">1W</b-button>
              <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24 * 14)" v-b-tooltip.hover.bottom.d300 :title="$t('2 weeks')">2W</b-button>
              <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24 * 28)" v-b-tooltip.hover.bottom.d300 :title="$t('1 month')">1M</b-button>
              <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24 * 28 * 2)" v-b-tooltip.hover.bottom.d300 :title="$t('2 months')">2M</b-button>
              <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24 * 28 * 6)" v-b-tooltip.hover.bottom.d300 :title="$t('6 months')">6M</b-button>
              <b-button variant="light" @click="setRangeByPeriod(60 * 60 * 24 * 365)" v-b-tooltip.hover.bottom.d300 :title="$t('1 year')">1Y</b-button>
            </b-button-group>
        </b-form-row>
      </b-popover>
      <base-input-group-date-time v-model="startDate"
        :placeholder="$i18n.t('Start')" :disabled="disabled" :max="maxStartDate" class="mr-1" />
      <base-input-group-date-time v-model="endDate"
        :placeholder="$i18n.t('End')" :disabled="disabled" :min="minEndDate" />
      <b-btn variant="link" :disabled="disabled || (!startDate && !endDate)" @click="clearRange">
        <icon name="trash-alt"></icon>
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
    default: () => ({ start_date: undefined, end_date: undefined })
  }
}

import { computed, customRef, ref, toRefs } from '@vue/composition-api'
import { format, subSeconds } from 'date-fns'

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
      emit('input', { ...value.value, start_date })
      trigger()
    }
  }))
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
      emit('input', { ...value.value, end_date })
      trigger()
    }
  }))
  const minEndDate = computed(() => {
    if (!startDate.value || startDate.value.replace(/[0-9]/g, '0') === '0000-00-00 00:00:00')
      return startDate.value
    return '0000-00-00 00:00:00'
  })

  const showPeriod = ref(false)

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

  return {
    startDate,
    maxStartDate,
    endDate,
    minEndDate,
    showPeriod,
    setRangeByPeriod,
    clearRange
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