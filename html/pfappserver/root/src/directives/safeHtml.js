import DOMPurify from 'dompurify'

/**
 * `v-safe-html` — a sanitizing drop-in replacement for `v-html`.
 *
 * Use this instead of `v-html` whenever the bound value can carry data that is
 * not a hard-coded developer literal (resource ids/names, API error messages,
 * monitoring values, anything interpolated through vue-i18n — which does NOT
 * HTML-escape its `{placeholders}`). It preserves the light formatting our
 * i18n strings / titles / notifications legitimately use while stripping
 * anything scriptable (scripts, event handlers, javascript: URLs, etc.).
 */
const CONFIG = {
  ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'code', 'span', 'a', 'br'],
  ALLOWED_ATTR: ['href', 'target', 'rel', 'class'],
  ALLOW_DATA_ATTR: false
}

const set = (el, binding) => {
  el.innerHTML = DOMPurify.sanitize(String(binding.value == null ? '' : binding.value), CONFIG)
}

export default {
  inserted: set,
  update: set
}
