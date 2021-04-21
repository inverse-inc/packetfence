<template>
  <b-tab :title="$t('Settings')">
    <b-card no-body class="mb-3">
      <b-card-header>
        <h4>{{ $t('Settings') }}</h4>
        <p class="mb-0">{{ $t('Changes are automatically saved.') }}</p>
      </b-card-header>
      <b-card-body class="p-3">
        <base-form-group
          :column-label="$t('Language')"
          :text="$t('Language is set after login and may be temporarily overridden from the header menu.')"
        >
          <div>
            <b-form-radio v-model="settings.language" name="language" :value="'en'">{{ $t('English') }}</b-form-radio>
            <b-form-radio v-model="settings.language" name="language" :value="'fr'">{{ $t('French') }}</b-form-radio>
            <b-form-radio v-model="settings.language" name="language" :value="null">{{ $t('Use web browser default') }}</b-form-radio>
          </div>
        </base-form-group>
      </b-card-body>
    </b-card>
    <b-card no-body>
      <b-card-header>
        <h4 class="mb-0">{{ $t('Change Password') }}</h4>
      </b-card-header>
      <b-card-body class="p-3">
        <b-form @submit.prevent ref="rootRef">
          <base-form
            :form="form"
            :schema="schema"
            :isLoading="isLoading"
          >
            <base-form-group-input-password namespace="current_password"
              :column-label="$t('Current password')" />
            <base-form-group-input-password-generator namespace="new_password"
              :column-label="$t('New password')" />
            <base-form-group-input-password namespace="confirm_new_password"
              :column-label="$t('Re-enter new password')" />
          </base-form>
        </b-form>
      </b-card-body>
      <b-card-footer>
        <b-button @click="changePassword"
          :disabled="isLoading || !isValid"
          variant="primary"
        >{{ $t('Change Password') }}</b-button>
      </b-card-footer>
    </b-card>
  </b-tab>
</template>
<script>
import {
  BaseForm,
  BaseFormGroup,
  BaseFormGroupInputPassword,
  BaseFormGroupInputPasswordGenerator
} from '@/components/new/'

const components = {
  BaseForm,
  BaseFormGroup,
  BaseFormGroupInputPassword,
  BaseFormGroupInputPasswordGenerator
}

import { computed, ref } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import { usePreference } from '@/composables/usePreferences'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import usersApi from '@/views/Users/_api'

yup.addMethod(yup.string, 'passwordsMatch', function (match) {
  return this.test({
    name: 'passwordsMatch',
    message: i18n.t('Does not match new password.'),
    test: value => {
      return (!value || !match || value === match)
    }
  })
})

const defaults = () => ({
  current_password: null,
  new_password: null,
  confirm_new_password: null
})

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const settings = usePreference('settings', { language: null })

  const rootRef = ref(null)
  const form = ref(defaults())

  const schema = computed(() => yup.object().shape({
    current_password: yup.string().nullable()
      .required(i18n.t('Current password required.')),
    new_password: yup.string().nullable()
      .required(i18n.t('New password required.')),
      //.min(6, i18n.t('Password must be at least 6 characters.')),
    confirm_new_password: yup.string().nullable()
      .required(i18n.t('Confirm new password.'))
      .passwordsMatch(form.value.new_password)
  }))
  const isLoading = ref(false)
  const isValid = useDebouncedWatchHandler(
    [form],
    () => (
      !rootRef.value ||
      Array.prototype.slice.call(rootRef.value.querySelectorAll('.is-invalid'))
        .filter(el => el.closest('fieldset').style.display !== 'none') // handle v-show <.. style="display: none;">
        .length === 0
    )
  )

  const changePassword = () => {
    isLoading.value = true
    const username = $store.state.session.username
    $store.dispatch('session/login', { username, password: form.value.current_password })
      .catch(err => { // invalid current_password
        $store.dispatch('notification/danger', { message: i18n.t('Current password is incorrect, could not change password.') })
        isLoading.value = false
        throw err
      })
      .then(() => { // valid current_password
        usersApi.updatePassword({ quiet: true, pid: username, password: form.value.new_password })
          .then(() => {
            $store.dispatch('notification/info', { message: i18n.t('Password changed successfully.') })
            form.value = defaults() // reset form
          })
          .finally(() => {
            isLoading.value = false
          })
      })
  }

  return {
    // settings
    settings,

    // password
    rootRef,
    form,
    schema,
    isLoading,
    isValid,
    changePassword
  }
}

// @vue/component
export default {
  name: 'tab-settings',
  inheritAttrs: false,
  components,
  setup
}
</script>