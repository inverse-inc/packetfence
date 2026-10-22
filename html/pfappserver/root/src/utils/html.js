/**
 * Minimal HTML-escape for values interpolated into `v-html` sinks that must NOT
 * allow ANY markup (e.g. SVG `<tspan>` builders where DOMPurify's HTML profile
 * would strip the intended markup). For sinks that legitimately render light
 * formatting, use the `v-safe-html` directive instead.
 */
export const escapeHtml = (value) => String(value == null ? '' : value)
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&#39;')

export default escapeHtml
