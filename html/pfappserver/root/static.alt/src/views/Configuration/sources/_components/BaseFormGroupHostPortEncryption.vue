<template>
  <b-form-group ref="form-group"
    class="base-form-group"
    :class="{
      'mb-0': !columnLabel
    }"
    :labelCols="labelCols"
    :label="columnLabel"
  >
    <b-input-group>

      <b-row class="w-100 mx-0 mb-1 px-0" align-v="center" no-gutters>
        <b-col sm="6" align-self="start">

          <base-input-select-multiple ref="hostRef"
            :namespace="namespaces[0]"
            :taggable="true"
          />

        </b-col>
        <b-col sm="3" align-self="start" class="pl-1">

          <base-input-number ref="portRef"
            :namespace="namespaces[1]"
          />

        </b-col>
        <b-col sm="3" align-self="start" class="pl-1">

          <base-input-select-one ref="encryptionRef"
            :namespace="namespaces[2]"
          />

        </b-col>
      </b-row>

      <div class="alert alert-warning w-100 mb-0" v-if="note">
        <strong>{{ $i18n.t('Note:') }}</strong>
        {{ note }}
      </div>

    </b-input-group>
    <template v-slot:description v-if="inputText">
      <div v-html="inputText"/>
    </template>
  </b-form-group>
</template>
<script>
import {
  BaseInputNumber,
  BaseInputSelectOne,
  BaseInputSelectMultiple
} from '@/components/new'

const components = {
  BaseInputNumber,
  BaseInputSelectOne,
  BaseInputSelectMultiple
}

import { computed, inject, nextTick, ref, toRefs, unref, watch } from '@vue/composition-api'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInputMetaProps } from '@/composables/useMeta'
import { useInputProps } from '@/composables/useInput'
import { setFormNamespace } from '@/composables/useInputValue'
import i18n from '@/utils/locale'

const props = {
  ...useFormGroupProps,
  ...useInputMetaProps,
  ...useInputProps,

  namespaces: {
    type: Array,
    default: () => (['host', 'port', 'encryption']),
    validator: value => value.length === 3
  }
}

const setup = (props, context) => {

  const {
    namespaces,
    text
  } = toRefs(props)

  const hostRef = ref(null)
  const portRef = ref(null)
  const encryptionRef = ref(null)

  const form = inject('form', ref({}))

  const note = computed(() => {
    const { encryption, port } = form.value
    switch (encryption) {
      case 'none':
      case 'starttls':
        if (~~port !== 389)
          return i18n.t('Port {port} is standard for {encryption} encryption.', { encryption: encryption.toUpperCase(), port: 389 })
        break
      case 'ssl':
        if (~~port !== 636)
          return i18n.t('Port {port} is standard for {encryption} encryption.', { encryption: encryption.toUpperCase(), port: 636 })
        break
    }
    return undefined
  })

  watch( // when `encryption` is mutated
    () => unref(form) && unref(form).encryption,
    encryption => {
      const { isFocus = false } = encryptionRef.value
      const { port } = form.value
      if (isFocus && !port) { // and `encryption` isFocus, and `port` is not set
        switch (encryption) { // set `port`
          case 'none':
          case 'starttls':
            setFormNamespace(unref(namespaces)[1].split('.'), unref(form), 389)
            break
          case 'ssl':
            setFormNamespace(unref(namespaces)[1].split('.'), unref(form), 636)
            break
        }
      }
    }
  )

  return {
    hostRef,
    portRef,
    encryptionRef,
    note,

    inputText: text
  }
}

// @vue/component
export default {
  name: 'base-form-group-host-port-encryption',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
