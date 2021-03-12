<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'Administrator'"/>
    </b-card-header>
    <b-form>
      <base-form
        :form="form"
        :schema="schema"
        :isLoading="isLoading"
      >
        <form-group-pid namespace="pid"
          :column-label="$i18n.t('Username')"
          :text="$i18n.t('Administrator username.')"
          readonly
        />

        <form-group-password namespace="password"
          :column-label="$i18n.t('Password')"
          :readonly="disabled"
        />

        <base-form-group v-if="isPassword"
          class="mb-3">
          <b-button variant="outline-primary" class="col-sm-7 col-lg-5 col-xl-4"
            @click="onClipboard">{{ $t('Copy to Clipboard') }}</b-button>
        </base-form-group>
      </base-form>
    </b-form>
  </b-card>
</template>
<script>
import {
  BaseForm,
  BaseFormGroup,
  BaseFormGroupInput,
  BaseFormGroupInputPasswordGenerator
} from '@/components/new/'

const components = {
  BaseForm,
  BaseFormGroup,

  FormGroupPid:      BaseFormGroupInput,
  FormGroupPassword: BaseFormGroupInputPasswordGenerator
}

const props = {
  disabled: {
    type: Boolean
  }
}

import { computed, inject, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const schemaFn = () => yup.object({
  pid: yup.string().nullable().required(i18n.t('Administrator username required.')),
  password: yup.string().nullable().required(i18n.t('Administrator password required.'))
})

export const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const state = inject('state') // Configurator
  const form = ref({
    pid: 'admin'
  })

  const schema = computed(() => schemaFn(props))

  const userExists = ref(false)
  $store.dispatch('$_users/getUser', { pid: 'admin', quiet: true }).then(_form => {
    userExists.value = true
    form.value = _form
  }).catch(() => {
    // User doesn't exist or database is not accessible
    form.value.pid = 'admin'
  })

  const isLoading = computed(() => $store.getters['$_users/isLoading'])
  const isPassword = computed(() => form.value && form.value.password)

  const onClipboard = () => {
    try {
      navigator.clipboard.writeText(form.value.password).then(() => {
        $store.dispatch('notification/info', { message: i18n.t('Password copied to clipboard') })
      }).catch(() => {
        $store.dispatch('notification/danger', { message: i18n.t('Could not copy password to clipboard.') })
      })
    } catch (e) {
      $store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
    }
  }

  const onSave = () => {
    let savePromise = new Promise((resolve, reject) => {
      const { pid, password } = form.value
      form.value.valid_from = "1970-01-01 00:00:00"
      if (userExists.value) {
        $store.dispatch('$_users/updatePassword', Object.assign({ quiet: true }, { pid, password })).then(resolve, reject)
      } else {
        $store.dispatch('$_users/getUser', { pid: 'admin', quiet: true }).then(() => {
          // User exists
          userExists.value = true
          $store.dispatch('$_users/updatePassword', Object.assign({ quiet: true }, { pid, password })).then(resolve, reject)
        }).catch(() => {
          // User doesn't exist
          $store.dispatch('$_users/createUser', form.value).then(() => {
            $store.dispatch('$_users/createPassword', Object.assign({ quiet: true }, form.value)).then(resolve, reject)
          }).catch(reject)
        })
      }
    })
    return savePromise
      .then(() => state.value.administrator = form.value)
      .catch(error => {
        // Only show a notification in case of a failure
        const { response: { data: { message = '' } = {} } = {} } = error
        $store.dispatch('notification/danger', {
          icon: 'exclamation-triangle',
          url: message,
          message: i18n.t('An error occured while setting the administrator password.')
        })
        throw error
      })
  }

  return {
    form,
    schema,
    userExists,
    isLoading,
    isPassword,
    onClipboard,
    onSave
  }
}

// @vue/component
export default {
  name: 'form-administrator',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
