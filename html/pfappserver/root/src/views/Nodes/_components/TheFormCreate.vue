<template>
  <b-form @submit.prevent ref="rootRef">
    <base-form
      :form="form"
      :schema="schema"
      :is-loading="isLoading"
    >
      <form-group-mac namespace="mac"
        :column-label="$t('MAC')"
      />
      <form-group-pid namespace="pid"
        :column-label="$i18n.t('Owner')"
        placeholder="default"
      />
      <form-group-status namespace="status"
        :column-label="$t('Status')"
      />
      <form-group-role namespace="category_id"
        :column-label="$t('Role')"
      />
      <form-group-unregdate namespace="unregdate"
        :column-label="$i18n.t('Unregistration')"
      />
      <form-group-computername namespace="computername"
        :column-label="$t('ComputerName')"
      />
      <form-group-notes namespace="notes"
        :column-label="$i18n.t('Notes')"
      />
      <div class="mt-3">
        <div class="border-top p-3">
          <base-form-button-bar
            is-new
            :is-loading="isLoading"
            is-saveable
            :is-valid="isValid"
            :form-ref="rootRef"
            @close="onClose"
            @reset="onReset"
            @save="onCreate"
          />
        </div>
      </div>
    </base-form>
  </b-form>
</template>

<script>
import {
  BaseForm,
  BaseFormButtonBar
} from '@/components/new/'
import {
  FormGroupMac,
  FormGroupComputername,
  FormGroupPid,
  FormGroupStatus,
  FormGroupRole,
  FormGroupUnregdate,
  FormGroupNotes
} from './'

const components = {
  BaseForm,
  BaseFormButtonBar,

  FormGroupMac,
  FormGroupComputername,
  FormGroupPid,
  FormGroupStatus,
  FormGroupRole,
  FormGroupUnregdate,
  FormGroupNotes
}

import { computed, ref } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import { usePropsWrapper } from '@/composables/useProps'
import { useRouter, useStore } from '../_composables/useCollection'
import { createForm as defaults } from '../_config'
import { createSchema as schemaFn } from '../schema'

const setup = (props, context) => {

  const rootRef = ref(null)
  const form = ref({ ...defaults }) // dereferenced
  const schema = computed(() => schemaFn(props, form.value))

  const isValid = useDebouncedWatchHandler(
    [form],
    () => (
      !rootRef.value ||
      Array.prototype.slice.call(rootRef.value.querySelectorAll('.is-invalid'))
        .filter(el => el.closest('fieldset').style.display !== 'none') // handle v-show <.. style="display: none;">
        .length === 0
    )
  )

  const { root: { $router, $store } = {} } = context

  // merge props w/ params in useStore methods
  const _useStore = $store => usePropsWrapper(useStore($store), props)
  const {
    isLoading,
    createItem
  } = _useStore($store)

  const {
    goToCollection,
    goToItem,
  } = useRouter($router)

  const onClose = () => goToCollection(false)

  const onCreate = () => {
    if (!isValid.value)
      return
    createItem(form.value)
      .then(({ id: mac }) => goToItem({ mac }))
  }

  const onReset = () => {
    form.value = { ...defaults } // dereferenced
  }

  return {
    rootRef,
    form,
    schema,
    isLoading,
    isValid,
    onClose,
    onCreate,
    onReset
  }
}

// @vue/component
export default {
  name: 'the-form-create',
  inheritAttrs: false,
  components,
  setup
}
</script>
