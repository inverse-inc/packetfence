import {
  BDropdown,
  BDropdownItemButton
} from 'bootstrap-vue'

import pfFormInput from './pfFormInput'
import mixinScss from './mixin.scss' // mixin scoped scss
import {
  mixinFormHandlers,
  mixinFormModel,
  mixinFormState
} from '@/components/_mixins/'

export const renderSlots = (ctx, h) => {
//console.log('render')
  let powersInRange = ctx.powers.filter(power => power.multiplier <= ctx.max)
  let selectedLabel = ctx.powers[ctx.powerIndex].label || ''
/*
      <b-dropdown size="sm" v-if="prefixes.length > 0" variant="light">
        <template v-slot:button-content>
          <span class="mr-1">{{ currentPrefix.label  + units.label }}</span>
        </template>
        <template v-for="(prefix, index) in prefixesInRange">
          <b-dropdown-item-button :key="index" :active="currentPrefix.label === prefix.label" @click="changeMultiplier(index)">{{ $t(prefix.label + units.label) }}</b-dropdown-item-button>
        </template>
      </b-dropdown>
*/
  return [
    h(BDropdown, {
      staticClass: 'pf-input-dropdown',
      props: {
        size: 'sm',
        variant: 'light'
      },
      scopedSlots: {
        'button-content': () => [
          h('span', {
            staticClass: 'mr-1'
          }, [
          `${selectedLabel}${ctx.units.label}`
          ])
        ]
      }
    }, powersInRange.map((power, index) => {
        return h(BDropdownItemButton, {
          props: {
            active: ctx.powerIndex === index
          },
          on: {
            click: () => ctx.doChangePower(index)
          }
        }, [
          `${power.label}${ctx.units.label}`
        ])
      })
    )
  ]
}

// @vue/component
export default {
  name: 'pf-form-input-power',
  extends: pfFormInput,
  mixins: [
    mixinFormHandlers,
    mixinFormModel, // uses v-model
    mixinFormState,
    mixinScss
  ],
  props: {
    units: {
      type: Object,
      default: () => ({ label: 'B', name: 'bytes' })
    },
    max: {
      type: Number,
      default: 16 * Math.pow(1024, 6) // 16XB
    },
    powers: {
      type: Array,
      default: () => [
        { label: '',  name: '',      multiplier: Math.pow(1024, 0) },
        { label: 'k', name: 'kilo',  multiplier: Math.pow(1024, 1) },
        { label: 'M', name: 'mega',  multiplier: Math.pow(1024, 2) },
        { label: 'G', name: 'giga',  multiplier: Math.pow(1024, 3) },
        { label: 'T', name: 'tera',  multiplier: Math.pow(1024, 4) },
        { label: 'P', name: 'peta',  multiplier: Math.pow(1024, 5) },
        { label: 'X', name: 'exa',   multiplier: Math.pow(1024, 6) },
        { label: 'Z', name: 'zetta', multiplier: Math.pow(1024, 7) },
        { label: 'Y', name: 'yotta', multiplier: Math.pow(1024, 8) }
      ]
    }
  },
  data () {
    return {
      powerIndex: 0
    }
  },
  computed: {
    powersInRange () {
      return this.powers.filter(power => power.multiplier <= this.max)
    },
    localType () { // overload input type
      return 'number'
    },
    localScopedSlots () {
      return (h) => {
        return {
          ...this.$scopedSlots,
          append: ((this.$scopedSlots.append)
            ? props => [
                ...renderSlots(this, h),
                this.$scopedSlots.append(props)
              ]
            : () => renderSlots(this, h)
          )
        }
      }
    },
    localValue: { // overloads pfFormInput
      get () {
// called when localValue is mutated externally
        let inputValue = +this.inputValue
        if (inputValue !== 0) {
          // find LCD for value
          for (let i = this.powersInRange.length - 1; i >= 0; i--) {
            let quotient = inputValue / this.powers[i].multiplier
            if (Math.abs(quotient) >= 1 && quotient === Math.round(quotient)) {
              // eslint-disable-next-line vue/no-side-effects-in-computed-properties
              this.powerIndex = i
              return quotient.toString()
            }
          }
          // eslint-disable-next-line vue/no-side-effects-in-computed-properties
          this.powerIndex = 0
        }
        return this.inputValue
      },
      set (newValue) {
// called when localValue is mutated internally
        if (+newValue === 0) {
          this.inputValue = null
        } else {
          // scale up
          let multiplier = this.powers[this.powerIndex].multiplier
          this.inputValue = `${+newValue * multiplier}`
        }
      }
    }
  },
  methods: {
    doChangePower (newIndex) {
      let inputValue = +this.inputValue
      if (inputValue !== 0) {
        const curIndex = this.powerIndex
        const factor = this.powers[newIndex].multiplier / this.powers[curIndex].multiplier
        this.inputValue = `${inputValue * factor}`
      } else {
        this.powerIndex = newIndex
      }
    }
  }
}
