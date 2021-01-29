<template>
  <b-card no-body>
    <b-card-header>
      <b-button-close @click="onClose" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"/></b-button-close>
      <pf-button-refresh class="border-right pr-3" :is-loading="isLoading" @refresh="refresh"></pf-button-refresh>
      <h4 class="d-inline mb-0">MAC <strong v-text="id"></strong></h4>
    </b-card-header>
    <b-tabs ref="tabsRef" v-model="tabIndex" card>
      <b-form @submit.prevent="onSave" ref="rootRef">
        <the-form
          :form="form"
          :id="id"
          :is-loading="isLoading"
          v-bind="$props"
        />
      </b-form>
    </b-tabs>
    <b-card-footer v-if="ifTab(['Edit', 'Location', 'Fingerbank', 'SecurityEvents'])">
      <form-button-bar class="mr-3"
        :actionKey="actionKey"
        :actionKeyButtonVerb="actionKeyButtonVerb"
        :isLoading="isLoading"
        isCloneable="false"
        isSaveable="true"
        :isDeletable="isDeletable"
        :isValid="isValid"
        :formRef="rootRef"
        @close="onClose"
        @remove="onRemove"
        @reset="onReset"
        @save="onSave"
      />
      <template v-if="ifTab(['Edit', 'Location'])">
        <template v-if="canReevaluateAccess">
          <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="isLoading" @click="applyReevaluateAccess">{{ $i18n.t('Reevaluate Access') }}</b-button>
        </template>
        <template v-else>
          <span v-b-tooltip.hover.top.d300 :title="$i18n.t('Node has no locations.')">
            <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="true">{{ $i18n.t('Reevaluate Access') }}</b-button>
          </span>
        </template>
      </template>
      <b-button class="mr-1" size="sm" v-if="ifTab(['Edit', 'Fingerbank'])" variant="outline-secondary" :disabled="isLoading" @click="applyRefreshFingerbank">{{ $i18n.t('Refresh Fingerbank') }}</b-button>
      <template v-if="ifTab(['Edit', 'Location'])">
        <template v-if="canRestartSwitchport">
          <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="isLoading" @click="applyRestartSwitchport">{{ $i18n.t('Restart Switch Port') }}</b-button>
        </template>
        <template v-else>
          <span v-b-tooltip.hover.top.d300 :title="$i18n.t('Node has no open wired connections.')">
            <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="true">{{ $i18n.t('Restart Switch Port') }}</b-button>
          </span>
        </template>
      </template>
      <template v-if="ifTab(['SecurityEvents']) && securityEventsOptions.length > 0">
        <div class="d-inline-flex">
          <form-security-events class="mr-1" size="sm"
            v-model="triggerSecurityEvent"
            :options="securityEventsOptions"
          />
          <b-button size="sm" variant="outline-secondary" @click="onTriggerSecurityEvent" :disabled="isLoading || !triggerSecurityEvent">{{ $t('Trigger New Security Event') }}</b-button>
        </div>
      </template>
    </b-card-footer>
  </b-card>
</template>

<script>
import network from '@/utils/network'
import { computed, ref, watch } from '@vue/composition-api'
import pfButtonRefresh from '@/components/pfButtonRefresh'
import { useRouter, useStore } from '../_composables/useCollection'
import {
  FormButtonBar,
  FormSecurityEvents,
  TheForm
} from './'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import useEventActionKey from '@/composables/useEventActionKey'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import useEventJail from '@/composables/useEventJail'

const components = {
  FormButtonBar,
  FormSecurityEvents,
  TheForm,
  pfButtonRefresh
}

const props = {
  id: { // from router
    type: String
  }
}

const setup = (props, context) => {

  // template refs
  const rootRef = ref(null)
  useEventJail(rootRef)

  const tabsRef = ref(null)
  const tabIndex = ref(0)

  // state
  const form = ref({})
  const isModified = ref(false)
  const triggerSecurityEvent = ref(null)

  const isValid = useDebouncedWatchHandler(
    [form],
    () => (
      !rootRef.value ||
      Array.prototype.slice.call(rootRef.value.querySelectorAll('.is-invalid'))
        .filter(el => el.closest('fieldset').style.display !== 'none') // handle v-show <.. style="display: none;">
        .length === 0
    )
  )

  const ifTab = (set) => {
    const { tabs = [] } = tabsRef.value || {}
    return tabs.length && set.includes(tabs[tabIndex.value].title)
  }

  const {
    isLoading,
    reloadItem,
    deleteItem,
    getItem,
    updateItem,
    reevaluateAccess,
    refreshFingerbank,
    restartSwitchport,
    sortedSecurityEvents,
    applySecurityEvent
  } = useStore(props, context, form)

  const {
    goToCollection,
    goToItem,
  } = useRouter(props, context, form)

  const isDeletable = computed(() => {
    const { not_deletable: notDeletable = false } = form.value || {}
    if (notDeletable)
      return false
    return true
  })

  const canReevaluateAccess = computed(() => {
    return (form && form.value.locations && form.value.locations.length > 0)
  })

  const canRestartSwitchport = computed(() => {
    return (form && form.value.locations && form.value.locations.filter(node =>
      node.end_time === '0000-00-00 00:00:00' && // require zero end_time
      network.connectionTypeToAttributes(node.connection_type).isWired // require 'Wired'
    ).length > 0)
  })

  const securityEventsOptions = computed(() => {
    return sortedSecurityEvents()
      .filter(securityEvent => securityEvent.id !== 'defaults')
      .map(securityEvent => { return { text: securityEvent.desc, value: securityEvent.id } })
  })

  const init = () => {
    return new Promise((resolve, reject) => {
      getItem().then(item => {
        form.value = item
        resolve()
      }).catch(e => {
        form.value = {}
        reject(e)
      })
    })
  }

  const save = () => updateItem()

  const onRefresh = () => reloadItem()

  const onClose = () => goToCollection()

  const onRemove = () => deleteItem().then(() => goToCollection())

  const onReset = () => init().then(() => isModified.value = false)

  const actionKey = useEventActionKey(rootRef)
  const onSave = () => {
    isModified.value = true
    const closeAfter = actionKey.value
    save().then(() => {
      if (closeAfter) // [CTRL] key pressed
        goToCollection(true)
      else
        goToItem().then(() => init()) // re-init
    })
  }

  const applyReevaluateAccess = () => reevaluateAccess()

  const applyRefreshFingerbank = () => refreshFingerbank()

  const applyRestartSwitchport = () => restartSwitchport()

  const onTriggerSecurityEvent = () => applySecurityEvent(triggerSecurityEvent)

  const escapeKey = useEventEscapeKey(rootRef)
  watch(escapeKey, () => goToCollection())

  watch(props, () => init(), { deep: true, immediate: true })

  return {
    rootRef,
    tabsRef,
    tabIndex,

    form,
    isModified,
    triggerSecurityEvent,
    // securityEvents,
    securityEventsOptions,

    ifTab,
    actionKey,
    isDeletable,
    isValid,
    isLoading,

    onRefresh,
    onClose,
    onRemove,
    onReset,
    onSave,
    canReevaluateAccess,
    canRestartSwitchport,

    applyReevaluateAccess,
    applyRefreshFingerbank,
    applyRestartSwitchport,
    onTriggerSecurityEvent
  }
}

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
