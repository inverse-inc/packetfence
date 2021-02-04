<template>
  <base-step ref="rootRef"
    :name="$t('Configure PacketFence')"
    icon="cogs"
    :invalid-step="!isValid"
    :invalid-feedback="invalidFeedback"
    :progress-feedback="progressFeedback"
    :is-loading="isLoading"
    @next="onSave">
    <form-database ref="databaseRef" :disabled="isLoading" />
    <form-general ref="generalRef" :disabled="isLoading" class="mt-3" />
    <form-alerting ref="alertingRef" :disabled="isLoading" class="mt-3" />
    <form-administrator ref="administratorRef" :disabled="isLoading" class="mt-3" />
  </base-step>
</template>
<script>
import BaseStep from '../../_components/BaseStep'
import FormAdministrator from './FormAdministrator'
import FormAlerting from './FormAlerting'
import FormDatabase from './FormDatabase'
import FormGeneral from './FormGeneral'

const components = {
  BaseStep,

  FormAdministrator,
  FormAlerting,
  FormDatabase,
  FormGeneral
}

import { computed, ref } from '@vue/composition-api'
import { useQuerySelectorAll } from '@/composables/useDom'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const { refs, root: { $router } = {} } = context

  const rootRef = ref(null)
  const isLoading = ref(false)

  // avoid having to pass events (state/invalidfeedback) up from deeply nested children within <router-view/>
  //  use DOM querySelectorAll with MutationObserver instead
  const _invalidNodes = useQuerySelectorAll(rootRef, '.is-invalid')
  const isValid = computed(() => (!_invalidNodes.value || _invalidNodes.value.length === 0))
  const invalidFeedback = computed(() => (_invalidNodes.value && Array.prototype.slice.call(_invalidNodes.value)
    .map(node => {
      let selection = node.querySelector('.invalid-feedback') // query children
      if (!selection)
        selection = node.parentNode.querySelector('.invalid-feedback') // query siblings
      if (selection)
        return selection.textContent
    })
    .reduce((strings, string) => { // unique, non-empty
      if (string && !strings.includes(string))
        strings.push(string)
      return strings
    }, [])
    .join(' ')
  ))

  const progressFeedback = ref(null)
  const onSave = nextRoute => {
    progressFeedback.value = i18n.t('Updating database configuration')
    isLoading.value = true
    const { databaseRef, generalRef, alertingRef, administratorRef } = refs
    isLoading.value = true
    databaseRef.onSave().then(() => {
      progressFeedback.value = i18n.t('Updating general and alerting configuration')
      return Promise.all([
        generalRef.onSave(),
        alertingRef.onSave()
      ]).then(() => {
        progressFeedback.value = i18n.t('Updating administrator account')
        return administratorRef.onSave()
      })
    }).then(() => {
      progressFeedback.value = i18n.t('Loading next step')
      $router.push(nextRoute)
    }).catch(() => {
      isLoading.value = false
    })
  }

  return {
    rootRef,
    isLoading,
    isValid,
    invalidFeedback,
    progressFeedback,
    onSave
  }
}


// @vue/component
export default {
  name: 'the-step',
  components,
  setup
}
</script>
