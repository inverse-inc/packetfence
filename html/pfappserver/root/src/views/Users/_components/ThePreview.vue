<template>
  <b-card no-body ref="rootRef">
    <b-card-header>
      <b-button-close @click="onClose" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0" v-t="'Preview Messages for Created Users'"></h4>
    </b-card-header>
    <b-card-body>
      <div class="pb-5 d-print-none">
        <base-form-group-input :column-label="$t('Subject')"
          v-model="emailSubject"
          :text="$t('The subject used for email messages.')"/>
        <hr/>
      </div>
      <b-container class="my-5" v-if="isLoading">
        <b-row class="justify-content-md-center text-secondary">
            <b-col cols="12" md="auto">
            <icon name="circle-notch" scale="1.5" spin></icon>
            </b-col>
        </b-row>
      </b-container>
      <div class="shadow mb-4" v-for="template in usersTemplates" :key="template.pid">
        <b-container class="d-print-none" v-if="template.email" fluid>
          <base-form-group :column-label="$t('Subject')">{{ emailSubject }}</base-form-group>
          <base-form-group :column-label="$t('From')">{{ emailFrom }}</base-form-group>
          <base-form-group :column-label="$t('To')">{{ template.email }}</base-form-group>
        </b-container>
        <b-embed type="iframe" aspect="4by3" :src="iframeContent(template.html)"></b-embed>
      </div>
    </b-card-body>
    <b-card-footer>
      <b-button v-if="canSend"
        @click="onSend" variant="outline-primary" class="mr-1">{{ $i18n.t('Send') }}</b-button>
      <b-button variant="outline-primary"
        @click="onPrint">{{ $i18n.t('Print') }}</b-button>
    </b-card-footer>
  </b-card>
</template>

<script>
import {
  BaseFormGroup,
  BaseFormGroupInput
} from '@/components/new/'
const components = {
  BaseFormGroup,
  BaseFormGroupInput
}

import { computed, onMounted, ref, watch } from '@vue/composition-api'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import useEventJail from '@/composables/useEventJail'
import i18n from '@/utils/locale'
import { useRouter } from '../_router'
const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  const emailSubject = ref('')
  const emailFrom= ref('')
  const usersSortBy = ref('pid')
  const usersSortDesc = ref(false)

  const isLoading = computed(() => $store.getters['$_users/isLoading'])
  const usersTemplates = ref([])
  const users = computed(() => $store.state['$_users'].createdUsers)
  watch(users, () => {
    usersTemplates.value = []
    users.value.forEach(user => {
      $store.dispatch('$_users/previewEmail', user).then(response => {
        usersTemplates.value.push({ pid: user.pid, email: user.email, html: response.body })
      })
    })
  }, { immediate: true })

  const canSend = computed(() => users.value.find(user => user.email))

  const {
    goToCollection
  } = useRouter($router)

  // template refs
  const rootRef = ref(null)
  useEventJail(rootRef)
  const escapeKey = useEventEscapeKey(rootRef)
  watch(escapeKey, () => onClose())

  const onClose = () => goToCollection()

  const iframeContent = html => `data:text/html;charset=utf-8,${escape(html)}`

  const onSend = () => {
    Promise.all(users.value.filter(user => user.email).map(user => {
      const data = {
        ...user,
        ...{
          subject: emailSubject.value
        }
      }
      return $store.dispatch('$_users/sendEmail', data)
    })).then(results => {
      $store.dispatch('notification/info', { message: i18n.t('{count} messages sent', { count: results.length }) })
    })
  }

  const onPrint = () => window.print()

  onMounted(() => {
    if (users.value.length === 0) {
      goToCollection()
      return
    }
    $store.dispatch('config/getBaseGeneral').then(general => {
      emailSubject.value = `${general.domain}: Guest account creation information`
    })
    $store.dispatch('config/getBaseAlerting').then(alerting => {
      if (alerting.fromaddr) {
        emailFrom.value = alerting.fromaddr
      }
      else {
        $store.dispatch('config/getBaseGeneral').then(general => {
          emailFrom.value = `root@${general.hostname}.${general.domain}`
        })
      }
    })
  })

  return {
    rootRef,

    isLoading,
    emailSubject,
    emailFrom,
    usersSortBy,
    usersSortDesc,
    usersTemplates,
    canSend,
    onClose,
    onSend,
    onPrint,
    iframeContent
  }
}

// @vue/component
export default {
  name: 'the-preview',
  components,
  setup
}
</script>

<style lang="scss">
@media print {
  .card-header,
  .card-footer,
  .notifications,
  .notifications-toasts {
    display: none !important;
  }
  .card {
    border: 0 !important;
  }
  .card-body {
    flex: none !important;
    padding: 0 !important;
    .shadow {
      box-shadow: none !important;
    }
  }
  .embed-responsive {
    height: 10in;
    page-break-after: always;
  }
}
</style>
