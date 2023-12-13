import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

import {
  digests as _digests,
  keyTypes as _keyTypes,
  keyUsages as _keyUsages,
  extendedKeyUsages as _extendedKeyUsages,
  revokeReasons as _revokeReasons,
} from '@/globals/pki'

export const digests = Object.entries(_digests).map(([value, text]) => ({ value: `${value}`, text }))

export const keyTypes = Object.entries(_keyTypes).map(([value, [text, sizes]]) => ({ value: `${value}`, text, sizes: sizes.map(s => `${s}`) }))

export const keySizes = [...(new Set(
    keyTypes.reduce((sizes, type) => ([ ...sizes, ...type.sizes.map(size => +size) ]), [])
  ))]
  .sort((a, b) => (a > b))
  .map(size => ({ value: `${size}`, text: `${size}` }))

export const keyUsages = Object.entries(_keyUsages).map(([value, text]) => ({ value: `${value}`, text }))

export const extendedKeyUsages = Object.entries(_extendedKeyUsages).map(([value, text]) => ({ value: `${value}`, text }))

export const revokeReasons = Object.entries(_revokeReasons).map(([value, text]) => ({ value: `${value}`, text }))

export const useServices = () => computed(() => {
  return {
    message: i18n.t('Creating or modifying the PKI configuration requires services restart.'),
    services: ['pfpki'],
    k8s_services: ['pfpki']
  }
})