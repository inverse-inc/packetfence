<template>
  <b-form @submit.prevent="onSave" ref="rootRef">
    <base-form
      :form="form"
      :schema="schema"
      :is-loading="isLoading"
      class="pt-0"
    >
      <form-group-pid namespace="pid"
        :column-label="$i18n.t('Owner')"
        placeholder="default"
      />
      <form-group-status namespace="status"
        :column-label="$i18n.t('Status')"
      />
      <form-group-role namespace="category_id"
        :column-label="$i18n.t('Role')"
      />
      <form-group-unregdate namespace="unregdate"
        :column-label="$i18n.t('Unregistration')"
      />
      <form-group-time-balance namespace="time_balance"
        :column-label="$i18n.t('Access Time Balance')"
        :text="$i18n.t('Seconds')"
      />
      <form-group-bandwidth-balance namespace="bandwidth_balance"
        :column-label="$i18n.t('Bandwidth Balance')"
        :max="MysqlLimits.ubigint.max"
      />
      <form-group-voip namespace="voip"
        :column-label="$i18n.t('Voice Over IP')"
      />
      <form-group-bypass-vlan namespace="bypass_vlan"
        :column-label="$i18n.t('Bypass VLAN')"
      />
      <form-group-bypass-role namespace="bypass_role_id"
        :column-label="$i18n.t('Bypass Role')"
      />
      <form-group-notes namespace="notes"
        :column-label="$i18n.t('Notes')"
      />

      <div class="mt-3">
        <div class="border-top pt-3">
          <form-button-bar
            :action-key="actionKey"
            :is-loading="isLoading"
            :is-cloneable="false"
            :is-saveable="true"
            :is-deletable="isDeletable"
            :is-valid="isValid"
            :form-ref="rootRef"
            @close="onClose"
            @remove="onRemove"
            @reset="onReset"
            @save="onSave"
          >
            <template v-if="canReevaluateAccess">
              <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="isLoading" @click="reevaluateAccess">{{ $i18n.t('Reevaluate Access') }}</b-button>
            </template>
            <template v-else>
              <span v-b-tooltip.hover.top.d300 :title="$i18n.t('Node has no locations.')">
                <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="true">{{ $i18n.t('Reevaluate Access') }}</b-button>
              </span>
            </template>
          </form-button-bar>
        </div>
      </div>
    </base-form>
  </b-form>
</template>

<script>
import {
  BaseForm,
  BaseFormGroupInput
} from '@/components/new/'
import {
  FormButtonBar,
  FormGroupPid,
  FormGroupStatus,
  FormGroupRole,
  FormGroupUnregdate,
  FormGroupTimeBalance,
  FormGroupBandwidthBalance,
  FormGroupVoip,
  FormGroupBypassVlan,
  FormGroupBypassRole,
  FormGroupNotes
} from './'

const components = {
  BaseForm,
  BaseFormGroupInput,

  FormButtonBar,
  FormGroupPid,
  FormGroupStatus,
  FormGroupRole,
  FormGroupUnregdate,
  FormGroupTimeBalance,
  FormGroupBandwidthBalance,
  FormGroupVoip,
  FormGroupBypassVlan,
  FormGroupBypassRole,
  FormGroupNotes
}

const props = {
  id: {
    type: String
  }
}

import { computed, ref, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import useEventActionKey from '@/composables/useEventActionKey'
import useEventJail from '@/composables/useEventJail'
import { MysqlLimits } from '@/globals/mysql'
import { updateSchema as schemaFn } from '../schema'
import { useRouter, useStore } from '../_composables/useCollection'

const setup = (props, context) => {

  // template refs
  const rootRef = ref(null)
  useEventJail(rootRef)

  // state
  const form = ref({})
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

const {
    isLoading,
    canReevaluateAccess,
    reloadItem,
    deleteItem,
    getItem,
    updateItem,
    reevaluateAccess
  } = useStore(props, context, form)

  const { root: { $router } = {} } = context
  const {
    goToCollection,
    goToItem,
  } = useRouter($router)

  const isDeletable = computed(() => {
    const { not_deletable: notDeletable = false } = form.value || {}
    if (notDeletable)
      return false
    return true
  })

  const init = () => {
    return new Promise((resolve, reject) => {
      getItem().then(item => {
        form.value = { ...item }
        resolve()
      }).catch(e => {
        form.value = {}
        reject(e)
      })
    })
  }

  const save = () => updateItem()

  const onRefresh = () => reloadItem()

  const onClose = () => goToCollection(false)

  const onRemove = () => deleteItem().then(() => goToCollection(false))

  const onReset = () => init()

  const actionKey = useEventActionKey(rootRef)
  const onSave = () => {
    const closeAfter = actionKey.value
    save().then(response => {
      if (closeAfter) // [CTRL] key pressed
        goToCollection(true)
      else {
        form.value = { ...form.value, ...response } // merge form w/ newly inserted IDs
        goToItem(form.value).then(() => init()) // re-init
      }
    })
  }

  watch(props, () => init(), { deep: true, immediate: true })

  return {
    MysqlLimits,

    rootRef,
    form,
    schema,
    actionKey,
    isDeletable,
    isValid,
    isLoading,
    canReevaluateAccess,

    onRefresh,
    onClose,
    onRemove,
    onReset,
    onSave,
    reevaluateAccess
  }
}

// @vue/component
export default {
  name: 'the-form-update',
  components,
  props,
  setup
}
</script>
