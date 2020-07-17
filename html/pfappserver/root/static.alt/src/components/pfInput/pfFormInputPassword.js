import {
  BButton,
  BButtonGroup,
  BPopover
} from 'bootstrap-vue'
import * as Icon from 'vue-awesome'

import pfFormInput from './pfFormInput'
import pfStaticGeneratePassword from './pfStaticGeneratePassword'
import mixinScss from './mixin.scss' // mixin scoped scss
import {
  mixinFormHandlers,
  mixinFormModel,
  mixinFormState
} from '@/components/_mixins/'

export const renderSlots = (ctx, h) => {
  const $GenBButton = h(BButton, {
    ref: 'button-generate',
    staticClass: 'input-group-text',
    props: {
      disabled: ctx.disabled,
      variant: 'secondary'
    },
    attrs: {
      id: `button-${ctx._uid}`,
      'aria-label': ctx.$i18n.t('Generate password'),
      tabIndex: '-1', // ignore
      title: ctx.$i18n.t('Generate password'),
    }
  }, [
    h(Icon, { props: { name: 'random' } })
  ])

  const $GenBPopover = (ctx.$popover = h(BPopover, {
    ref: 'popover-generate',
    props: {
      placement: 'bottom',
      triggers: 'focus blur click',
      target: `button-${ctx._uid}`,
      title: ctx.$i18n.t('Generate password')
    }
  }, [
    h(pfStaticGeneratePassword, {
      on: {
        input: ctx.doSetPassword,
        mouseover: ctx.doShowPasword,
        mousemove: ctx.doShowPassword,
        mouseout: ctx.doHidePassword
      }
    }, [])
  ]))

  const $EyeBButton = h(BButton, {
    ref: 'button-reveal',
    staticClass: 'input-group-text',
    props: {
      disabled: ctx.disabled,
      variant: (ctx.pinVisibility) ? 'primary' : 'secondary'
    },
    attrs: {
      id: ctx._uid,
      'aria-label': ctx.$i18n.t('Reveal password'),
      tabIndex: '-1', // ignore
      title: ctx.$i18n.t('Reveal password'),
    },
    on: {
      focus: (event) => { // don't persist focus, avoid button:focus CSS
        const { target } = event
        target.blur()
      },
      click: ctx.doToggleVisibility,
      mouseover: ctx.doShowPassword,
      mousemove: ctx.doShowPassword,
      mouseout: ctx.doHidePassword
    }
  }, [
    h(Icon, { props: { name: 'eye' } })
  ])

  return [
    h(BButtonGroup, {
      staticClass: 'pf-input-button-group'
    }, [
      $GenBButton,
      $EyeBButton,
      $GenBPopover
    ])
  ]
}

// @vue/component
export default {
  name: 'pf-form-input-password',
  extends: pfFormInput,
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
          ...this.$slots,
          append: ((this.$slots.append)
            ? props => [
                ...renderSlots(this, h),
                this.$slots.append(props)
              ]
            : () => renderSlots(this, h)
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
