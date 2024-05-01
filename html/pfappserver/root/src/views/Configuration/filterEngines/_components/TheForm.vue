<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >

    <form-group-type v-if="fields.includes('type')"
                     namespace="type"
                    :column-label="$i18n.t('Type')"
                    disabled
    />

    <form-group-filter-enabled v-if="fields.includes('status')"
                               namespace="status"
                               :column-label="$i18n.t('Enabled')"
                               enabled-value="enabled"
                               disabled-value="disabled"
    />

    <form-group-identifier namespace="id"
                           :column-label="$i18n.t('Name')"
                           :text="$i18n.t('Specify a unique name for your filter.')"
                           :disabled="!isNew && !isClone"
    />

    <form-group-description v-if="fields.includes('description')"
                            namespace="description"
                            :column-label="$i18n.t('Description')"
    />

    <form-group-condition v-if="fields.includes('condition')"
                          namespace="condition"
                          :column-label="$i18n.t('Condition')"
                          :text="$i18n.t('Specify a condition to match.')"
    />

    <form-group-run-actions v-if="fields.includes('actions')"
                            namespace="run_actions"
                            :column-label="$i18n.t('Perform Actions')"
                            :text="$i18n.t('Enable to perform the following actions. Disable to only apply the role.')"
                            enabled-value="enabled"
                            disabled-value="disabled"
    />

    <form-group-actions v-if="fields.includes('actions') && form.run_actions === 'enabled'"
                        namespace="actions"
                        :column-label="$i18n.t('Actions')"
                        :text="$i18n.t('Specify actions to perform when condition is met.')"
    />

    <form-group-actions-synchronous v-if="fields.includes('actions')"
                                    namespace="actions_synchronous"
                                    :column-label="$i18n.t('Perform Actions Synchronously')"
                                    :text="$i18n.t('By default, actions are performing asynchronously to the request. Enable this to make them synchronous so that the result of the actions may impact the current RADIUS request.')"
                                    enabled-value="enabled"
                                    disabled-value="disabled"
    />

    <form-group-log v-if="fields.includes('log')"
                    namespace="log"
                    :column-label="$i18n.t('Log Entry')"
                    :text="$i18n.t('Specify the message to write to packetfence.log')"
    />

    <form-group-params v-if="fields.includes('params')"
                       namespace="params"
                       :column-label="$i18n.t('Parameters')"
                       :text="$i18n.t('Specify parameters to apply when condition is met.')"
    />

    <form-group-merge-answer v-if="fields.includes('merge_answer')"
                             namespace="merge_answer"
                             :column-label="$i18n.t('Merge Answer')"
                             :text="$i18n.t('Enable to merge the following answers with the original RADIUS answers.')"
                             enabled-value="yes"
                             disabled-value="no"
    />

    <form-group-answers v-if="fields.includes('answers')"
                        namespace="answers"
                        :column-label="$i18n.t('Answers')"
    />

    <form-group-answer v-if="fields.includes('answer')"
                       namespace="answer"
                       :column-label="$i18n.t('Answer')"
    />

    <form-group-role v-if="fields.includes('role')"
                     namespace="role"
                     :column-label="$i18n.t('Role')"
    />

    <form-group-scopes v-if="fields.includes('scopes')"
                       namespace="scopes"
                       :column-label="$i18n.t('Scopes')"
    />

    <form-group-network-switch v-if="fields.includes('switch')"
                               namespace="switch"
                               :column-label="$i18n.t('Switch')"
                               :text="$i18n.t('Specify which switch module to use.')"
    />

    <form-group-response-code v-if="fields.includes('rcode')"
                              namespace="rcode"
                              :column-label="$i18n.t('Response Code')"
    />

    <form-group-radius-status v-if="fields.includes('radius_status')"
                              namespace="radius_status"
                              :column-label="$i18n.t('RADIUS Status')"
    />

  </base-form>
</template>
<script>
import {BaseForm,} from '@/components/new/'
import {
  FormGroupActions,
  FormGroupActionsSynchronous,
  FormGroupAnswer,
  FormGroupAnswers,
  FormGroupCondition,
  FormGroupDescription,
  FormGroupFilterEnabled,
  FormGroupIdentifier,
  FormGroupLog,
  FormGroupMergeAnswer,
  FormGroupNetworkSwitch,
  FormGroupParams,
  FormGroupRadiusStatus,
  FormGroupResponseCode,
  FormGroupRole,
  FormGroupRunActions,
  FormGroupScopes,
  FormGroupType,
} from './'
import {useForm, useFormProps as props} from '../_composables/useForm'

const components = {
  BaseForm,
  FormGroupActions,
  FormGroupActionsSynchronous,
  FormGroupAnswer,
  FormGroupAnswers,
  FormGroupCondition,
  FormGroupDescription,
  FormGroupFilterEnabled,
  FormGroupIdentifier,
  FormGroupLog,
  FormGroupMergeAnswer,
  FormGroupNetworkSwitch,
  FormGroupParams,
  FormGroupRadiusStatus,
  FormGroupResponseCode,
  FormGroupRole,
  FormGroupRunActions,
  FormGroupScopes,
  FormGroupType,
}

export const setup = (props, context) => useForm(props, context)

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
