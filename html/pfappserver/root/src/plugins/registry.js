/**
 * Admin UI plugins registry: the core components and validators a plugin
 * manifest may name (see docs/ui-plugins/README.md and catalog.json).
 *
 * A plugin page is built at runtime from its manifest, webpack cannot see which
 * components it uses. Every component of the catalog is referenced here by a
 * lazy loader, so it is always part of the build, even if no core view used it
 * anymore (today they all are already in the initial app chunk, imported by
 * the core views through @/components/new).
 *
 * Keep in sync with catalog.json, `node build/ui-plugins-catalog.js --check`
 * fails otherwise.
 */
import yup from '@/utils/yup'

/* eslint-disable key-spacing */
export const components = {
  BaseFormGroupInput: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupInput'),
  BaseFormGroupInputNumber: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupInputNumber'),
  BaseFormGroupInputPassword: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupInputPassword'),
  BaseFormGroupInputPasswordGenerator: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupInputPasswordGenerator'),
  BaseFormGroupTextarea: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupTextarea'),
  BaseFormGroupInputDate: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupInputDate'),
  BaseFormGroupInputDateTime: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupInputDateTime'),
  BaseFormGroupChosenOne: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupChosenOne'),
  BaseFormGroupChosenOneSearchable: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupChosenOneSearchable'),
  BaseFormGroupChosenTimezone: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupChosenTimezone'),
  BaseFormGroupChosenCountry: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupChosenCountry'),
  BaseFormGroupChosenMultiple: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupChosenMultiple'),
  BaseFormGroupChosenMultipleSearchable: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupChosenMultipleSearchable'),
  BaseFormGroupSwitch: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupSwitch'),
  BaseFormGroupToggle: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupToggle'),
  BaseFormGroupToggleDisabledEnabled: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupToggleDisabledEnabled'),
  BaseFormGroupToggleNoYes: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupToggleNoYes'),
  BaseFormGroupToggleNY: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupToggleNY'),
  BaseFormGroupToggleOffOn: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupToggleOffOn'),
  BaseFormGroupToggleFalseTrue: () => import(/* webpackChunkName: "plugins" */ '@/components/new/BaseFormGroupToggleFalseTrue')
}
/* eslint-enable key-spacing */

// the yup schema of a value, by component type (catalog.json)
export const types = {
  string: () => yup.string().nullable(),
  array: () => yup.array().ensure(),
  mixed: () => yup.mixed()
}

// (schema, args, message) => schema, message is undefined for the default one
/* eslint-disable no-unused-vars */
export const validators = {
  required: (s, a, m) => s.required(m),
  min: (s, a, m) => s.min(a[0], m),
  max: (s, a, m) => s.max(a[0], m),
  matches: (s, a, m) => s.matches(new RegExp(a[0]), m),
  email: (s, a, m) => s.email(m),
  url: (s, a, m) => s.url(m),
  in: (s, a, m) => s.in(a[0], m),
  not: (s, a, m) => s.not(a[0], m),
  minAsInt: (s, a, m) => s.minAsInt(a[0], m),
  maxAsInt: (s, a, m) => s.maxAsInt(a[0], m),
  isAlphaNumeric: (s, a, m) => s.isAlphaNumeric(m),
  isAlphaNumericHyphenUnderscoreDot: (s, a, m) => s.isAlphaNumericHyphenUnderscoreDot(m),
  isUUID: (s, a, m) => s.isUUID(m),
  isCIDR: (s, a, m) => s.isCIDR(m),
  isCommonName: (s, a, m) => s.isCommonName(m),
  isCommonNameOrFQDN: (s, a, m) => s.isCommonNameOrFQDN(m),
  isCommonNameOrFQDNOrMAC: (s, a, m) => s.isCommonNameOrFQDNOrMAC(m),
  isDomain: (s, a, m) => s.isDomain(m),
  isEmailCsv: (s, a, m) => s.isEmailCsv(m),
  isFilename: (s, a, m) => s.isFilename(m),
  isFQDN: (s, a, m) => s.isFQDN(m),
  isLowerCase: (s, a, m) => s.isLowerCase(m),
  isHostname: (s, a, m) => s.isHostname(m),
  isIpv4: (s, a, m) => s.isIpv4(m),
  isIpv4Csv: (s, a, m) => s.isIpv4Csv(m),
  isIpv6: (s, a, m) => s.isIpv6(m),
  isMAC: (s, a, m) => s.isMAC(m),
  isPort: (s, a, m) => s.isPort(1, 65535, m),
  isPortCsv: (s, a, m) => s.isPortCsv(m),
  isPrice: (s, a, m) => s.isPrice(m),
  isStaticRoute: (s, a, m) => s.isStaticRoute(m),
  isVLAN: (s, a, m) => s.isVLAN(m),
  unique: (s, a, m) => s.unique(m)
}
/* eslint-enable no-unused-vars */
