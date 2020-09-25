<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >

    <!--
    @type: Htpasswd
    -->
    <template v-if="form.type === 'Htpasswd'">
      <form-group-identifier namespace="id"
        :column-label="$i18n.t('Name')"
        :disabled="!isNew && !isClone"
      />

      <form-group-notes namespace="notes"
        :column-label="$i18n.t('Description')"
      />

      <form-group-max-nodes-per-pid namespace="max_nodes_per_pid"
        type="number"
        :column-label="$i18n.t('Max nodes per user')"
        :text="$i18n.t('The maximum number of nodes a user having this role can register. A number of 0 means unlimited number of devices.')"
      />
    </template>

    <b-container class="my-5" v-else>
      <b-row class="justify-content-md-center text-secondary">
        <b-col cols="12" md="auto">
          <b-media v-if="isLoading">
            <template v-slot:aside><icon v-if="isLoading" name="circle-notch" scale="2" spin></icon></template>
            <h4>{{ $t('Loading Form') }}</h4>
            <p class="font-weight-light">{{ $t('Hold on a moment while we render it...') }}</p>
          </b-media>
          <b-media v-else>
            <template v-slot:aside><icon name="question-circle" scale="2"></icon></template>
            <h4>{{ $t('Unhandled source type') }}</h4>
          </b-media>
        </b-col>
      </b-row>
    </b-container>

  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupMaxNodesPerPid,
  FormGroupNotes
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupMaxNodesPerPid,
  FormGroupNotes
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
  },
  isLoading: {
    type: Boolean,
    default: false
  },

  id: {
    type: String
  },
  sourceType: {
    type: String
  }
}

export const setup = (props) => {
  const schema = computed(() => schemaFn(props))

  return {
    schema
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

