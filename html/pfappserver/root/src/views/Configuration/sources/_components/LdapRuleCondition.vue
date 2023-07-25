<template>
  <div class="base-flex-wrap" align-v="center">
    <ldap-attribute-selector ref="attributeComponentRef"
                             :namespace="`${namespace}.attribute`"
    />

    <base-input-chosen-one ref="operatorComponentRef" v-if="attributeValue"
                           :namespace="`${namespace}.operator`"
                           :options="operatorOptions"
    />

    <component :is="valueComponent" ref="valueComponentRef" v-if="operatorValue"
               :namespace="`${namespace}.value`"
               v-bind="valueBind"
    />

  </div>
</template>
<script>
import {BaseInput, BaseInputChosenOne} from '@/components/new'
import {computed, nextTick, ref, unref, watch} from '@vue/composition-api'
import {
  operatorMap,
  pfComponentType,
  pfFieldType,
  pfFieldTypeOperators as fieldTypeOperators,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'
import {useInputMeta, useInputMetaProps} from '@/composables/useMeta'
import {useInputValue, useInputValueProps} from '@/composables/useInputValue'
import LdapSearchInput
  from '@/views/Configuration/sources/_components/ldapCondition/LdapSearchInput.vue';
import LdapAttributeSelector
  from '@/views/Configuration/sources/_components/ldapCondition/LdapAttributeSelector.vue';

const components = {
  BaseInputChosenOne,
  LdapAttributeSelector,
  BaseInput,
}

const props = {
  ...useInputMetaProps,
  ...useInputValueProps,
}

const setup = (props, context) => {

  const ldapSearchOperators = [operatorMap.is, operatorMap.equals, operatorMap.not_equals]

  const metaProps = useInputMeta(props, context)

  const {
    value: inputValue,
    onChange
  } = useInputValue(metaProps, context)

  const attributeComponentRef = ref(null)
  const operatorComponentRef = ref(null)
  const valueComponentRef = ref(null)

  watch( // when `attribute` is mutated
    () => unref(inputValue) && unref(inputValue).attribute,
    () => {
      const {isFocus = false} = attributeComponentRef.value
      if (isFocus) { // and `attribute` isFocus
        onChange({...unref(inputValue), operator: undefined, value: undefined}) // clear `operator` and `value`

        nextTick(() => {
          const {
            doFocus = () => {
            }
          } = operatorComponentRef.value || {}
          doFocus() // focus `operator` component
        })
      }
    }
  )

  watch( // when `operator` is mutated
    () => unref(inputValue) && unref(inputValue).operator,
    () => {
      const {isFocus = false} = operatorComponentRef.value
      if (isFocus) { // and `operator` isFocus
        onChange({...unref(inputValue), value: undefined}) // clear `value`

        nextTick(() => {
          const {
            doFocus = () => {
            }
          } = valueComponentRef.value || {}
          doFocus() // focus `value` component
        })
      }
    }
  )

  const attributeValue = computed(() => {
    const {attribute} = unref(inputValue) || {}
    return attribute
  })

  const operatorOptions = computed(() => {
    return fieldTypeOperators[pfFieldType.LDAPATTRIBUTE]
  })

  const operatorValue = computed(() => {
    const {operator} = unref(inputValue) || {}
    return operator
  })

  const valueComponent = computed(() => {
    if (attributeValue.value) {
      if (ldapSearchOperators.includes(operatorValue.value))
        return LdapSearchInput
      else
        return BaseInput
    } else {
      return undefined
    }
  })

  const valueBind = computed(() => {
    const {attributes: {'data-type': type} = {}} = unref(attributeValue) || {}
    if (type && type in fieldTypeValues) {
      const options = fieldTypeValues[type]()
      if (0 in options && 'group' in options[0]) // grouped
        return {groupSelect: true, groupLabel: 'group', groupValues: 'options', options}
      else // non-grouped
        return {options}
    }
    return undefined
  })

  const doFocus = () => {
    const {
      doFocus = () => {
      }
    } = attributeComponentRef.value || {}
    doFocus() // focus `attribute` component
  }

  return {
    attributeComponentRef,
    attributeValue,

    operatorComponentRef,
    operatorOptions,
    operatorValue,

    valueComponentRef,
    valueComponent,
    valueBind,

    doFocus
  }
}

// @vue/component
export default {
  name: 'ldap-rule-condition',
  computed: {
    pfComponentType() {
      return pfComponentType
    },
  },
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
