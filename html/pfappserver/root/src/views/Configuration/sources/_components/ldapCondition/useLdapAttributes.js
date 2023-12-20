import {computed, provide, ref, watch} from '@vue/composition-api';
import _ from 'lodash';
import ProvidedKeys from '@/views/Configuration/sources/_components/ldapCondition/ProvidedKeys';
import useAdLdap from '@/views/Configuration/sources/_components/ldapCondition/useAdLdap';
import useOpenLdap from '@/views/Configuration/sources/_components/ldapCondition/useOpenLdap';

const useLdapAttributes = (props) => {
  const form = computed(() => props.form)
  const ldapClient = getLdapClient(form)

  function connectionCheck() {
    ldapClient.checkConnection().then((connected) => {
      connectedToLdap.value = connected
    })
  }

  const debouncedConnectionCheck = _.debounce(connectionCheck, 1000)
  const connectedToLdap = ref(false)
  const ldapAttributes = ref([])
  const ldapAttributesLoading = ref(false)

  watch(form, debouncedConnectionCheck, {deep: true})

  watch(connectedToLdap, (newConnectionState) => {
    const { type } = form.value || {}
    const extras = (type === 'AD') ? ['memberOf:1.2.840.113556.1.4.1941'] : []
    if (newConnectionState === true) {
      ldapAttributesLoading.value = true
      ldapClient.getAttributes().then((attributes) => {
        ldapAttributes.value = [...attributes, ...extras]
        ldapAttributesLoading.value = false
      })
    } else {
      ldapAttributes.value = extras
    }
  })

  ldapClient.checkConnection().then((connected) => {connectedToLdap.value = connected})
  provide(ProvidedKeys.LdapAttributes, ldapAttributes)
  provide(ProvidedKeys.connectedToLdap, connectedToLdap)
  provide(ProvidedKeys.LdapAttributesLoading, ldapAttributesLoading)
  provide(ProvidedKeys.performSearch, ldapClient.performSearch)

  return {form, connectedToLdap}
}

function getLdapClient(form) {
  switch (form.value.type) {
    case 'AD':
      return useAdLdap(form)
    default:
      return useOpenLdap(form)
  }
}

export default useLdapAttributes
