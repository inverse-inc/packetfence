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

    <b-card no-body class="mb-3">
      <b-card-header>
        <h4>{{ $t('Change Password') }}</h4>
        <p class="mb-0">{{ $t('Local users only.') }}</p>
      </b-card-header>
      <b-card-body class="p-3">
        <!-- local user -->
        <b-form v-if="isLocalUser"
          @submit.prevent ref="rootRef">
          <base-form
            :form="form"
            :schema="schema"
            :is-loading="isLoading"
          >
            <base-form-group-input-password namespace="current_password"
              :column-label="$t('Current password')" />
            <base-form-group-input-password-generator namespace="new_password"
              :column-label="$t('New password')" />
            <base-form-group-input-password namespace="confirm_new_password"
              :column-label="$t('Re-enter new password')" />
          </base-form>
        </b-form>
        <!-- external user -->
        <b-container class="my-5" v-else>
          <b-row class="justify-content-md-center text-secondary">
            <b-col cols="12" md="auto">
              <icon v-if="isLoading" name="circle-notch" scale="1.5" spin></icon>
              <b-media v-else>
                <template v-slot:aside><icon name="user-lock" scale="2"></icon></template>
                <h4>{{ $t('User is not local') }}</h4>
                <p class="font-weight-light">{{ $t('The password can not be changed for external users.') }}</p>
              </b-media>
            </b-col>
          </b-row>
        </b-container>
      </b-card-body>
      <b-card-footer v-if="isLocalUser">
        <b-button @click="changePassword"
          :disabled="isLoading || !isValid"
          variant="primary"
        >{{ $t('Change Password') }}</b-button>
      </b-card-footer>
    </b-card>

    <b-card no-body>
      <b-card-header>
        <h4>{{ $t('Preferences') }}</h4>
        <b-button variant="outline-primary" @click="showPreferencesImport = true">{{ $t('Import') }}</b-button>
      </b-card-header>
      <b-card-body class="p-3">
        <b-table ref="preferencesTableRef"
          :items="preferences"
          :fields="preferencesFields"
          hover striped selectable class="mb-0"
          @row-selected="onPreferencesSelected"
        >
          <template #head(selected)>
            <span @click="onPreferencesToggled">
              <template v-if="preferencesSelected.length > 0">
                <icon name="check-square" class="bg-white text-success" scale="1.125"/>
              </template>
              <template v-else>
                <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
              </template>
            </span>
          </template>
          <template #cell(selected)="{ rowSelected }">
            <template v-if="rowSelected">
              <icon name="check-square" class="bg-white text-success" scale="1.125" />
            </template>
            <template v-else>
              <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
            </template>
          </template>
          <template #custom-foot>
            <tr>
              <td colspan="100%">
                <b-button
                  variant="outline-primary" class="mr-1"
                  :disabled="preferencesSelected.length === 0"
                  @click="onPreferencesSelectedExport"
                >{{ $t('Export Selected') }}</b-button>
                <base-button-confirm
                  variant="outline-danger" class="mr-1"
                  :disabled="preferencesSelected.length === 0"
                  :confirm="$t('Delete selected preferences?')"
                  @click="onPreferencesSelectedDelete"
                >{{ $t('Delete Selected') }}</base-button-confirm>
              </td>
            </tr>
          </template>
        </b-table>
      </b-card-body>
    </b-card>
    <b-modal v-model="showPreferencesExport" @hide="showPreferencesExport = false"
      size="lg" titleTag="div" centered>
      <template v-slot:modal-title>
        <h4 class="mb-0" v-html="$t('Export Preferences')"></h4>
      </template>
      <base-input-group-textarea
        v-model="preferencesExport"
        readOnly rows="10"
      />
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="showPreferencesExport = false">{{ $t('Close') }}</b-button>
        <b-button variant="primary" class="mr-1" @click="doPreferencesExport">{{ $t('Copy to Clipboard') }}</b-button>
      </template>
    </b-modal>
    <b-modal v-model="showPreferencesImport" @hide="showPreferencesImport = false"
      size="lg" title-tag="div" centered
      :hide-header-close="isLoading" :no-close-on-backdrop="isLoading" :no-close-on-esc="isLoading">
      <template v-slot:modal-title>
        <h4 v-html="$t('Import Preferences')"></h4>
        <p class="mb-0">{{ $t('Existing preferences with the same identifier will be overwritten.') }}</p>
      </template>
      <base-input-group-textarea
        v-model="preferencesImport"
        :disabled="isLoading"
        rows="10"
      />
      <b-alert :show="!!preferencesImportError"
        class="mb-0 mt-3" variant="warning" fade>{{ preferencesImportError }}</b-alert>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1"
          :disabled="isLoading" @click="showPreferencesImport = false">{{ $t('Cancel') }}</b-button>
        <base-button-save variant="primary" class="mr-1"
          :disabled="!preferencesImport" :is-loading="isLoading" @click="doPreferencesImport">{{ $t('Import') }}</base-button-save>
      </template>
    </b-modal>
  </b-tab>
</template>
<script>
import {
  BaseButtonConfirm,
  BaseButtonSave,
  BaseForm,
  BaseFormGroup,
  BaseFormGroupInputPassword,
  BaseFormGroupInputPasswordGenerator,
  BaseInputGroupTextarea
} from '@/components/new/'

const components = {
  BaseButtonConfirm,
  BaseButtonSave,
  BaseForm,
  BaseFormGroup,
  BaseFormGroupInputPassword,
  BaseFormGroupInputPasswordGenerator,
  BaseInputGroupTextarea
}

import { computed, nextTick, ref, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
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

  const { refs, root: { $store } = {} } = context

  const settings = ref({ language: null })
  $store.dispatch('preferences/all')
    .then(() => {
      settings.value = { ...settings.value, ...$store.state.preferences.cache['settings'] || {} }
      nextTick(() => { // avoid race
        watch(settings, () => {
          $store.dispatch('preferences/set', { id: 'settings', value: settings.value })
        }, { deep: true })
      })
      watch(() => settings.value.language, lang => {
        if (lang) { // use settings language
          $store.dispatch('session/setLanguage', { lang })
        }
        else { // use browser language
          lang = window.navigator.language.split(/-/)[0]
          if (!['en', 'fr'].includes(lang))
            lang = 'en'
          $store.dispatch('session/setLanguage', { lang })
        }
      })
    })

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
  const isValid = useDebouncedWatchHandler(
    [form],
    () => (
      !rootRef.value ||
      Array.prototype.slice.call(rootRef.value.querySelectorAll('.is-invalid'))
        .filter(el => el.closest('fieldset').style.display !== 'none') // handle v-show <.. style="display: none;">
        .length === 0
    )
  )

  const isLoading = ref(true)
  const isLocalUser = ref(false)
  $store.dispatch('$_users/getUser', { pid: $store.state.session.username, quiet: true })
    .then(response => {
      const { has_password } = response || {}
      isLocalUser.value = !!has_password

    })
    .finally(() => {
      isLoading.value = false
    })

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

  const preferences = computed(() => {
    return Object.keys($store.state.preferences.cache)
      .map(id => ({ id, ...$store.state.preferences.cache[id] }))
      .filter(({ id, ...rest }) => Object.keys(rest).length > 0)
    })

  const preferencesFields = [
    {
      label: '', // selected
      key: 'selected',
      thStyle: 'width: 40px;'
    },
    {
      label: i18n.t('Identifier'),
      key: 'id',
      sortable: true
    },
    {
      label: i18n.t('Created'),
      key: 'meta.created_at',
      formatter: value => ((new Date(value)).toISOString()),
      sortable: true
    },
    {
      label: i18n.t('Updated'),
      key: 'meta.updated_at',
      formatter: value => ((new Date(value)).toISOString()),
      sortable: true
    },
    {
      label: i18n.t('Version'),
      key: 'meta.version',
      sortable: true
    }
  ]
  const preferencesSelected = ref([])
  const onPreferencesSelected = value => {
    preferencesSelected.value = value.map(({id}) => id)
  }
  const onPreferencesToggled = () => {
    const { preferencesTableRef } = refs
    if (preferencesSelected.value.length === 0) // select all
      preferencesTableRef.selectAllRows()
    else // select none
      preferencesTableRef.clearSelected()
  }
  const onPreferencesSelectedDelete = () => {
    let promises = []
    preferencesSelected.value.forEach(id => {
      promises.push($store.dispatch('preferences/delete', id))
    })
    Promise.all(promises)
      .then(() => $store.dispatch('notification/info', { message: i18n.t('Preferences deleted.') }))
  }
  const preferencesExport = ref([])
  const showPreferencesExport = ref(false)
  const onPreferencesSelectedExport = () => {
    const xport = preferencesSelected.value.map(id => {
      const index = preferences.value.findIndex(preference => preference.id === id)
      return preferences.value[index]
    })
    preferencesExport.value = JSON.stringify(xport)
    showPreferencesExport.value = true
  }
  const doPreferencesExport = () => {
    showPreferencesExport.value = false
    try {
      navigator.clipboard.writeText(preferencesExport.value).then(() => {
        $store.dispatch('notification/info', { message: i18n.t('Preferences exported to clipboard.') })
      }).catch(() => {
        $store.dispatch('notification/danger', { message: i18n.t('Could not export preferences to clipboard.') })
      })
    } catch (e) {
      $store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
    }
  }
  const preferencesImport = ref(null)
  const preferencesImportError = ref(null)
  const showPreferencesImport = ref(false)
  const doPreferencesImport = () => {
    isLoading.value = true
    preferencesImportError.value = null
    let promises = []
    try {
      const parsed = JSON.parse(preferencesImport.value)
      parsed.forEach(preference => {
        const { id, meta, ...value } = preference
        promises.push($store.dispatch('preferences/set', { id, value }))
      })
      Promise.all(promises)
        .then(() => {
          preferencesImport.value = null
          showPreferencesImport.value = false
          $store.dispatch('notification/info', { message: i18n.t('Preferences imported.') })
        })
        .finally(() => isLoading.value = false)
    }
    catch (e) {
      preferencesImportError.value = i18n.t('Import is invalid or malformed JSON.')
    }
  }


  return {
    // settings
    settings,
    isLocalUser,

    // password
    rootRef,
    form,
    schema,
    isLoading,
    isValid,
    changePassword,

    // preferences
    preferences,
    preferencesFields,
    preferencesSelected,
    onPreferencesSelected,
    onPreferencesToggled,
    onPreferencesSelectedDelete,
    onPreferencesSelectedExport,

    preferencesExport,
    showPreferencesExport,
    doPreferencesExport,

    preferencesImport,
    preferencesImportError,
    showPreferencesImport,
    doPreferencesImport
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