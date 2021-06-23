<template>
  <b-dropdown v-bind="$attrs">
    <template #button-content>
      <template v-if="join.status === null">
        <icon name="circle-notch" class="mr-1" spin></icon> {{ $t('Joining...') }}
      </template>
      <template v-else-if="join.status === true">
        <icon name="circle" class="text-success mr-1"
          v-b-tooltip.hover.left.d300 :title="$t('Join success')"></icon> {{ $t('Join success') }}
      </template>
      <template v-else-if="join.status === false">
        <icon name="circle" class="text-danger mr-1"
          v-b-tooltip.hover.left.d300 :title="$t('Join failed')"></icon> {{ $t('Join failed') }}
      </template>
    </template>
    <b-dropdown-text v-if="join.message"
      class="px-3" :class="{
        'text-danger': join.status === false,
        'text-success': join.status === true
      }" v-t="join.message" />
    <b-dropdown-divider v-if="join.message" />
    <b-dropdown-item v-if="canJoin"
      @click="showJoin">{{ $t('Join') }}</b-dropdown-item>
    <b-dropdown-item v-if="canRejoin"
      @click="showJoin">{{ $t('Rejoin') }}</b-dropdown-item>
    <b-dropdown-item v-if="canUnjoin"
      @click="showUnjoin">{{ $t('Unjoin') }}</b-dropdown-item>
    <b-modal v-model="showJoinModal"
      size="lg" lazy centered id="joinModal">
      <template v-slot:modal-title>
        <h4 class="mb-0" v-html="$t('Join {id} domain', { id })"></h4>
        <b-form-text v-t="'Please enter administrative credentials to connect to the domain.'" class="mb-0"></b-form-text>
      </template>
      <b-form-group class="mb-0" ref="joinFormRef">
        <b-form @submit.prevent>
          <base-form
            :form="form"
            :schema="schema"
            :isLoading="isLoading"
          >
            <base-form-group-input namespace="username"
              :column-label="$t('Username')"
            />
            <base-form-group-input-password namespace="password"
              :column-label="$t('Password')"
            />
          </base-form>
        </b-form>
      </b-form-group>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="showJoinModal=false">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" :disabled="!isJoinValid" @click="doJoin">{{ $t('Join Domain') }}</b-button>
      </template>
    </b-modal>

    <b-modal v-model="showUnjoinModal"
      size="lg" lazy centered id="unjoinModal">
      <template v-slot:modal-title>
        <h4 class="mb-0" v-html="$t('Unjoin {id} domain', { id })"></h4>
        <b-form-text v-t="'Please enter administrative credentials to disconnect from the domain.'" class="mb-0"></b-form-text>
      </template>
      <b-form-group class="mb-0" ref="unjoinFormRef">
        <b-form @submit.prevent>
          <base-form
            :form="form"
            :schema="schema"
            :isLoading="isLoading"
          >
            <base-form-group-input namespace="username"
              :column-label="$t('Username')"
            />
            <base-form-group-input-password namespace="password"
              :column-label="$t('Password')"
            />
          </base-form>
        </b-form>
      </b-form-group>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="showUnjoinModal=false">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" :disabled="!isUnjoinValid" @click="doUnjoin">{{ $t('Unjoin Domain') }}</b-button>
      </template>
    </b-modal>

    <b-modal v-model="showWaitModal"
      size="lg" lazy centered id="waitModal"
      hide-header-close no-close-on-backdrop no-close-on-esc>
      <template v-slot:modal-title>
        <h4 class="mb-0" v-html="$t('Joining {id} domain', { id })"></h4>
        <b-form-text v-t="'Closing this dialog will not cancel the operation.'" class="mb-0"></b-form-text>
      </template>
      <b-container class="my-5">
        <b-row class="justify-content-md-center text-secondary">
          <b-col cols="12" md="auto">
            <b-media>
              <template v-slot:aside><icon name="circle-notch" scale="2" spin></icon></template>
                <h4>{{ $t('Please wait') }}</h4>
                <p class="mb-0">{{ $t('This operation may take a few minutes.') }}</p>
            </b-media>
          </b-col>
        </b-row>
      </b-container>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="showWaitModal=false">{{ $t('Close') }}</b-button>
      </template>
    </b-modal>

    <b-modal v-model="showResultModal" size="lg" lazy centered id="resultModal"
      hide-header-close no-close-on-backdrop no-close-on-esc>
      <template v-slot:modal-title>
        <h4 class="mb-0" v-html="$t('Join {id} domain', { id })"></h4>
      </template>
      <b-container class="my-3">
        <b-row class="justify-content-md-center text-secondary">
          <b-col cols="12" md="auto">
            <b-media v-if="join.status === true">
              <template v-slot:aside><icon name="check" scale="2" class="text-success"></icon></template>
              <h4 v-html="$t('Join {domain} domain succeded', { domain: $strong(id) })"></h4>
              <p class="font-weight-light text-pre mt-3 mb-0 text-wrap">{{ join.message }}</p>
            </b-media>
            <b-media v-else>
              <template v-slot:aside><icon name="times" scale="2" class="text-danger"></icon></template>
              <h4 v-html="$t('Join {domain} domain failed', { domain: $strong(id) })"></h4>
              <p class="font-weight-light text-pre mt-3 mb-0 text-wrap">{{ join.message }}</p>
            </b-media>
          </b-col>
        </b-row>
      </b-container>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="showResultModal=false">{{ $t('Close') }}</b-button>
        <b-button v-if="join.status !== true"
          variant="primary" @click="showJoinModal = true">{{ $t('Try again') }}</b-button>
      </template>
    </b-modal>
  </b-dropdown>
</template>
<script>
import {
  BaseForm,
  BaseFormGroupInput,
  BaseFormGroupInputPassword
} from '@/components/new/'

const components = {
  BaseForm,
  BaseFormGroupInput,
  BaseFormGroupInputPassword
}

export const props = {
  id: {
    type: String
  },
  size: {
    type: String
  },
  autoJoin: {
    type: Boolean
  }
}

import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const schemaFn = () => {
  return yup.object().shape({
    username: yup.string().nullable().required(i18n.t('Username required.')),
    password: yup.string().nullable().required(i18n.t('Password required.'))
  })
}

const defaults = {
  username: null,
  password: null
}

import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'

export const setup = (props, context) => {

  const { id, autoJoin } = toRefs(props)
  const { root: { $store } = {} } = context

  const form = ref({})
  const schema = computed(() => schemaFn(props))

  const domain = ref({})
  const join = ref({ status: null })
  watch(id, () => {
    form.value = { ...defaults }
    $store.dispatch('$_domains/getDomain', id.value)
      .then((response) => domain.value = response)
    $store.dispatch('$_domains/testDomain', id.value)
      .then((response) => join.value = response)
  }, { immediate: true })

  const isLoading = computed(() => $store.getters['$_domains/isLoading'])

  const showWaitModal = ref(false)
  const showResultModal = ref(false)

  const canJoin = computed(() => {
    const { status = false } = join.value
    return status === false
  })
  const joinFormRef = ref()
  const showJoinModal = ref(false)
  const showJoin = () => {
    showJoinModal.value = true
  }
  if (autoJoin.value)
    showJoin()
  const isJoinValid = useDebouncedWatchHandler([form, showJoinModal], () => {
    const { $el } = joinFormRef.value || {}
    return (!$el || $el.querySelectorAll('.is-invalid').length === 0)
  })
  const doJoin = () => {
    showJoinModal.value = false
    showWaitModal.value = true
    const { username, password } = form.value
    let promise
    if (canRejoin.value)
      promise = $store.dispatch('$_domains/rejoinDomain', { id: id.value, username, password })
    else
      promise = $store.dispatch('$_domains/joinDomain', { id: id.value, username, password })
    promise.finally(() => {
      showWaitModal.value = false
      showResultModal.value = true
    })
  }

  const canRejoin = computed(() => {
    const { status = false } = join.value
    return status === true
  })
  // ... rejoin reuses join modal/methods

  const canUnjoin = computed(() => {
    const { status = false } = join.value
    return status === true
  })
  const unjoinFormRef = ref()
  const showUnjoinModal = ref(false)
  const showUnjoin = () => {
    showUnjoinModal.value = true
  }
  const isUnjoinValid = useDebouncedWatchHandler([form, showUnjoinModal], () => {
    const { $el } = unjoinFormRef.value || {}
    return (!$el || $el.querySelectorAll('.is-invalid').length === 0)
  })
  const doUnjoin = () => {
    showUnjoinModal.value = false
    showWaitModal.value = true
    const { username, password } = form.value
    $store.dispatch('$_domains/unjoinDomain', { id: id.value, username, password })
      .finally(() => {
        showWaitModal.value = false
        showResultModal.value = true
      })
  }

  const doTryAgain = () => {
    showResultModal.value = false
    if (canUnjoin.value)
      showUnjoinModal.value = true
    else
      showJoinModal.value = true
  }

  return {
    domain,
    join,

    showWaitModal,
    showResultModal,
    doTryAgain,

    canJoin,
    joinFormRef,
    showJoin,
    showJoinModal,
    isJoinValid,
    doJoin,

    canRejoin,

    canUnjoin,
    unjoinFormRef,
    showUnjoin,
    showUnjoinModal,
    isUnjoinValid,
    doUnjoin,

    form,
    schema,
    isLoading
  }
}

// @vue/component
export default {
  name: 'base-button-join',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

