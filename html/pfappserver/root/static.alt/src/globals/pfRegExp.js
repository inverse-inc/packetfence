/**
 * The following PCRE definitions are used for form input.
 *
 *  The expression is compared after each keystroke, thus the
 *    expression must `RegExp.test(this.value)` true on each keystroke,
 *    otherwise the input field is reverted to the last known value
 *    which tested true.
 *
 *  This is not meant to be a validation replacement, but rather a
 *    helper that actively assists the user during form input.
 *
 *  See the `filter` property in:
 *    ../components/pfFormInput.vue
**/
export const pfRegExp = {
  none: null,
  integer: /^[-0-9]*$/,
  integerPositive: /^[0-9]*$/,
  float: /^[-0-9.]*$/,
  floatPositive: /^[0-9.]*$/,
  stringVlan: /^[0-9a-z]{1,50}$/i,
  stringMac: /^[0-9a-f:]{1,17}$/i,
  stringPhone: /^[0-9.,+\- ()]*$/i
}
