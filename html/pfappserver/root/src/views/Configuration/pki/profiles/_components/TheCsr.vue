<template>
  <b-card no-body>
    <b-form @submit.prevent ref="rootRef">
      <b-card-header>
        <b-button-close @click="onClose" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">
          {{ $t('Sign CSR') }}
        </h4>
      </b-card-header>
      <div class="card-body">
        <base-form
          :form="form"
          :schema="schema"
          :isLoading="isLoading"
        >
          <form-group-csr namespace="csr"
            :column-label="$i18n.t('Certificate Signing Request')"
            auto-fit
          />
        </base-form>
      </div>
      <b-card-footer>
        <base-form-button-bar
          :is-loading="isLoading"
          is-saveable
          :is-valid="isValid"
          :form-ref="rootRef"
          @close="onClose"
          @save="onSign"
          :label-save="$i18n.t('Sign')"
        />
      </b-card-footer>
    </b-form>
  </b-card>
</template>

<script>
import {
  BaseForm,
  BaseFormButtonBar
} from '@/components/new/'
import {
  FormGroupCsr
} from './'
const components = {
  BaseForm,
  BaseFormButtonBar,
  FormGroupCsr
}

const props = {
  id: {
    type: String
  }
}

import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import { useRouter, useStore } from '../_composables/useCollection'
import { useRouter as useCertRouter } from '../../certs/_composables/useCollection'
import { csrSchema as schemaFn } from '../schema'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $router, $store } = {} } = context

  const {
    goToItem
  } = useRouter($router)

  const {
    isLoading,
    signCsr
  } = useStore($store)

  const rootRef = ref(null)
  const form = ref({})
  const schema = computed(() => schemaFn())

  const isValid = useDebouncedWatchHandler(
    [form],
    () => (
      !rootRef.value ||
      Array.prototype.slice.call(rootRef.value.querySelectorAll('.is-invalid'))
        .filter(el => el.closest('fieldset').style.display !== 'none') // handle v-show <.. style="display: none;">
        .length === 0
    )
  )

  const onClose = () => goToItem({ ID: id.value })

  const onSign = () => {
    signCsr({ id: id.value, csr: form.value.csr }).then(response => {
      $store.dispatch('notification/info', { message: i18n.t('<code>{cn}</code> certificate created.', response) })
      useCertRouter($router).goToItem(response)
    })
  }

  const escapeKey = useEventEscapeKey(rootRef)
  watch(escapeKey, onClose)

  return {
    rootRef,
    isValid,
    onClose,
    onSign,


    form,
    schema,
    isLoading
  }
}

// @vue/component
export default {
  name: 'the-csr',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
