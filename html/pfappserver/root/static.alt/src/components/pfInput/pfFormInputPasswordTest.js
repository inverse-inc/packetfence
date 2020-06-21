import {
  BButton,
  BButtonGroup,
  BPopover
} from 'bootstrap-vue'
import * as Icon from 'vue-awesome'

import pfFormInputTest from './pfFormInputTest'
import { renderButtonGroup as renderButtonGroupPassword } from './pfFormInputPassword'
import { renderButtonGroup as renderButtonGroupTest } from './pfFormInputTest'
import pfStaticGeneratePassword from './pfStaticGeneratePassword'
import mixinScss from './mixin.scss' // mixin scoped scss
import {
  mixinFormHandlers,
  mixinFormModel,
  mixinFormState
} from '@/components/_mixins/'

// @vue/component
export default {
  name: 'pf-form-input-password-test',
  extends: pfFormInputTest,
  mixins: [
    mixinFormHandlers,
    mixinFormModel, // uses v-model
    mixinFormState,
    mixinScss
  ],
  data () {
    return {
      pinVisibility: false,
      showPassword: false
    }
  },
  created() {
    // Non reactive properties
    this.$popover = null
  },
  beforeDestroy() {
    // Destroy the BPopover instance
    this.$popover && this.$popover.$destroy()
    this.$popover = null
  },
  computed: {
    localType () {
      return (this.showPassword || this.pinVisibility) ? 'text' : 'password'
    },
    localScopedSlots () {
      return (h) => {
        return {
          ...this.$scopedSlots,
          append: ((this.$scopedSlots.append)
            ? props => [
                renderButtonGroupPassword(this, h),
                renderButtonGroupTest(this, h),
                this.$scopedSlots.append(props)
              ]
            : () => [
              renderButtonGroupPassword(this, h),
              renderButtonGroupTest(this, h)
            ]
          )
        }
      }
    }
  },
  methods: {
    doSetPassword (newPassword) {
      this.$emit('input', newPassword) // bubble
      this.localValue = newPassword
    },
    doShowPassword () {
      this.showPassword = true
    },
    doHidePassword () {
      this.showPassword = false
    },
    doToggleVisibility () {
      this.pinVisibility = !this.pinVisibility
    }
  }
}
