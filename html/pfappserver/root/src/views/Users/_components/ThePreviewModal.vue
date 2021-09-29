<template>
  <b-modal v-model="show" size="lg" :title="$t('The following users have been created')"
    centered no-close-on-backdrop no-close-on-esc lazy scrollable
  >
    <b-table
      :items="users"
      :fields="visibleUsersFields"
      :sortBy="usersSortBy"
      :sortDesc="usersSortDesc"
      show-empty responsive striped>
        <template v-slot:empty>
          <slot name="emptySearch" v-bind="{ isLoading }">
            <base-table-empty :is-loading="isLoading">{{ $t('No users created') }}</base-table-empty>
          </slot>
        </template>
      </b-table>
    <template v-slot:modal-footer>
      <div class="w-100">
        <b-button :disabled="isLoading" variant="primary" class="float-right" @click="goToPreview">{{ $i18n.t('Preview') }}</b-button>
      </div>
    </template>
  </b-modal>
</template>

<script>
import {
  BaseTableEmpty
} from '@/components/new/'

const components = {
  BaseTableEmpty
}

const props = {
  value: {
    type: Boolean
  }
}

import { computed, customRef, ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
const setup = (props, context) => {

  const {
    value
  } = toRefs(props)

  const { emit, root: { $store, $router } = {} } = context

  const emailSubject = ref('')
  const emailFrom = ref('')
  const usersSortBy = ref('pid')
  const usersSortDesc = ref(false)
  const usersFields = ref([
    {
      key: 'pid',
      label: i18n.t('Username'),
      sortable: true,
      visible: true
    },
    {
      key: 'email',
      label: i18n.t('Email'),
      sortable: true,
      visible: false
    },
    {
      key: 'password',
      label: i18n.t('Password'),
      sortable: false,
      visible: true
    }
  ])
  const visibleUsersFields = computed(() => usersFields.value.map(field => field.visible))

  const show = customRef((track, trigger) => ({
    get() {
      track()
      return value.value
    },
    set(newValue) {
      emit('input', newValue)
      trigger()
    }
  }))

  const isLoading = computed(() => $store.getters['$_users/isLoading'])
  const users = computed(() => $store.state['$_users'].createdUsers.map(({ pid, email, password }) => ({ pid, email, password })))
  const usersTemplates = computed(() => users.value.map(user => {
      return $store.dispatch('$_users/previewEmail', user).then(response => {
        return { pid: user.pid, email: user.email, html: response.body }
      })
  }))
  watch(users, () => {
    if (users.value.find(user => user.email)) {
      usersFields.value.find(field => field.key === 'email').visible = true
    }
  })

  const goToPreview = () => {
    show.value = false
    $router.push({ name: 'usersPreview' })
  }

  return {
    emailSubject,
    emailFrom,
    usersSortBy,
    usersSortDesc,
    usersFields,
    visibleUsersFields,
    isLoading,
    users,
    usersTemplates,

    show,
    goToPreview
  }
}

// @vue/component
export default {
  name: 'the-preview-modal',
  components,
  props,
  setup
}
</script>
