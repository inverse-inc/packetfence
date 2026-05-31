<template>
  <b-form-group class="base-form-group base-htpasswd-users"
    :state="state"
    :invalid-feedback="invalidFeedback"
    :label="$i18n.t('Users')"
    label-cols="3"
  >
    <b-container fluid class="px-0">

      <b-alert :show="!hasPath" variant="warning" class="mb-2">
        {{ $i18n.t('Save the source with a file path before managing users.') }}
      </b-alert>

      <template v-if="hasPath">
        <b-alert :show="!!message" :variant="messageVariant" dismissible
          @dismissed="message = ''"
        >{{ message }}</b-alert>

        <template v-if="!fileExists">
          <b-alert :show="true" variant="info" class="mb-2">
            {{ $i18n.t('The htpasswd file does not yet exist on the filesystem.') }}
          </b-alert>
          <b-button variant="outline-primary" :disabled="isLoading" @click="onCreateFile">
            <icon class="mr-1" name="file-medical" />{{ $i18n.t('Create new htpasswd file') }}
          </b-button>
        </template>

        <template v-else>
        <b-table :items="items" :fields="fields" :busy="isLoading"
          small hover responsive striped show-empty borderless
          :empty-text="$i18n.t('No users defined in the htpasswd file.')"
        >
          <template v-slot:cell(buttons)="{ item }">
            <div class="text-right text-nowrap">
              <b-button size="sm" variant="outline-secondary" class="my-1 mr-1"
                :disabled="isLoading"
                @click="onEdit(item)"
              >{{ $i18n.t('Change password') }}</b-button>
              <base-button-confirm size="sm" variant="outline-danger" class="my-1"
                :disabled="isLoading"
                :confirm="$i18n.t('Delete?')"
                reverse
                @click="onDelete(item)"
              >{{ $i18n.t('Delete') }}</base-button-confirm>
            </div>
          </template>
        </b-table>

        <b-button variant="outline-primary" :disabled="isLoading" @click="onAdd">
          <icon class="mr-1" name="plus-circle" />{{ $i18n.t('Add User') }}
        </b-button>

        <b-modal v-model="showModal" :title="modalTitle" centered no-close-on-backdrop
          :ok-disabled="isLoading || !modalUsername || !modalPassword"
          :ok-title="$i18n.t('Save')"
          :cancel-title="$i18n.t('Cancel')"
          @ok.prevent="onSave"
        >
          <b-form-group :label="$i18n.t('Username')" label-cols="4">
            <b-form-input v-model="modalUsername" :disabled="isEditing || isLoading" autofocus />
          </b-form-group>
          <b-form-group :label="$i18n.t('Password')" label-cols="4">
            <b-form-input v-model="modalPassword" type="password" :disabled="isLoading" />
          </b-form-group>
        </b-modal>
        </template>
      </template>

    </b-container>
  </b-form-group>
</template>
<script>
import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { BaseButtonConfirm } from '@/components/new/'
import i18n from '@/utils/locale'
import api from '../_api'

const components = {
  BaseButtonConfirm
}

const props = {
  id: {
    type: String
  },
  form: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  }
}

const setup = (props) => {

  const {
    id,
    form,
    isNew
  } = toRefs(props)

  const items = ref([])
  const isLoading = ref(false)
  const message = ref('')
  const messageVariant = ref('danger')
  const state = ref(null)
  const invalidFeedback = ref(undefined)
  const fileExists = ref(true)

  const fields = [
    { key: 'username', label: i18n.t('Username'), sortable: true },
    { key: 'buttons', label: '', class: 'text-right' }
  ]

  const hasPath = computed(() => {
    if (isNew.value) return false
    const path = (form.value || {}).path
    return !!(id.value && path)
  })

  const setError = msg => {
    message.value = msg
    messageVariant.value = 'danger'
  }
  const setInfo = msg => {
    message.value = msg
    messageVariant.value = 'success'
  }

  const reload = () => {
    if (!hasPath.value) return Promise.resolve()
    isLoading.value = true
    return api.htpasswdUsersList(id.value).then(data => {
      items.value = (data.items || []).map(username => ({ username }))
      fileExists.value = (data.file_exists !== false)
      state.value = null
    }).catch(err => {
      const msg = ((err.response || {}).data || {}).message || `${err}`
      setError(msg)
      state.value = false
      invalidFeedback.value = msg
    }).finally(() => {
      isLoading.value = false
    })
  }

  watch(
    () => [hasPath.value, (form.value || {}).path],
    () => { reload() },
    { immediate: true }
  )

  const showModal = ref(false)
  const isEditing = ref(false)
  const modalUsername = ref('')
  const modalPassword = ref('')
  const modalTitle = computed(() => isEditing.value
    ? i18n.t('Change password for {username}', { username: modalUsername.value })
    : i18n.t('Add User')
  )

  const onAdd = () => {
    isEditing.value = false
    modalUsername.value = ''
    modalPassword.value = ''
    showModal.value = true
  }

  const onEdit = item => {
    isEditing.value = true
    modalUsername.value = item.username
    modalPassword.value = ''
    showModal.value = true
  }

  const onSave = () => {
    const username = modalUsername.value
    const password = modalPassword.value
    if (!username || !password) return
    isLoading.value = true
    const promise = isEditing.value
      ? api.htpasswdUsersUpdate({ id: id.value, username, password })
      : api.htpasswdUsersCreate({ id: id.value, username, password })
    return promise.then(() => {
      setInfo(isEditing.value
        ? i18n.t('Password changed for {username}.', { username })
        : i18n.t('User {username} saved.', { username })
      )
      showModal.value = false
      return reload()
    }).catch(err => {
      const msg = ((err.response || {}).data || {}).message || `${err}`
      setError(msg)
    }).finally(() => {
      isLoading.value = false
    })
  }

  const onDelete = item => {
    isLoading.value = true
    return api.htpasswdUsersDelete({ id: id.value, username: item.username }).then(() => {
      setInfo(i18n.t('User {username} deleted.', { username: item.username }))
      return reload()
    }).catch(err => {
      const msg = ((err.response || {}).data || {}).message || `${err}`
      setError(msg)
    }).finally(() => {
      isLoading.value = false
    })
  }

  const onCreateFile = () => {
    isLoading.value = true
    return api.htpasswdFileCreate({ id: id.value }).then(() => {
      setInfo(i18n.t('Htpasswd file created and synced to all cluster members.'))
      return reload()
    }).catch(err => {
      const msg = ((err.response || {}).data || {}).message || `${err}`
      setError(msg)
    }).finally(() => {
      isLoading.value = false
    })
  }

  return {
    items,
    fields,
    isLoading,
    hasPath,
    fileExists,
    message,
    messageVariant,
    state,
    invalidFeedback,
    showModal,
    isEditing,
    modalTitle,
    modalUsername,
    modalPassword,
    onAdd,
    onEdit,
    onSave,
    onDelete,
    onCreateFile
  }
}

// @vue/component
export default {
  name: 'base-htpasswd-users',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
