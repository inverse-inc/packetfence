/**
 * Minimal markdown renderer for assistant replies.
 *
 * The input is escaped first, so only the markup produced here reaches v-html.
 * Besides the usual subset (fences, inline code, bold, links, headings, lists)
 * it turns menu paths the model writes ("Configuration > Policies and Access
 * Control > Connection Profiles") into links to the matching admin route, and
 * marks MAC addresses so the view can copy them on click.
 */

// \u0000-\u0002 are placeholders for held-aside fragments; the escaped input
// cannot contain them, so matching on them is intentional.
/* eslint-disable no-control-regex */

const esc = s => s.replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]))

// Menu LABELS are not URL segments: admin routes are flat slugs and the middle
// entry is only a menu heading. Resolve the LEAF label to a known route, fall
// back to the section root, and leave unknown paths unlinked so a nav link
// never lands on a missing route.
const ROUTES = {
  // top level
  'status': '#/status',
  'reports': '#/reports',
  'auditing': '#/auditing',
  'nodes': '#/nodes',
  'users': '#/users',
  'configuration': '#/configuration',
  // section landing pages
  'system configuration': '#/configuration/system_configuration',
  'policies and access control': '#/configuration/policies_access_control',
  'network configuration': '#/configuration/network_configuration',
  'compliance': '#/configuration/compliance',
  'integration': '#/configuration/integration',
  // labels whose route is NOT the snake_case of the label
  'ssl certificates': '#/configuration/certificates',
  'authentication sources': '#/configuration/sources',
  'sources': '#/configuration/sources',
  'active directory domain': '#/configuration/domains'
}
const norm = s => (s || '').toLowerCase().replace(/\s+/g, ' ').trim()
const slug = s => (s || '').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '')

const route = segs => {
  const leaf = norm(segs[segs.length - 1])
  if (ROUTES[leaf])
    return ROUTES[leaf]
  const head = norm(segs[0])
  // under Configuration the leaf is a page: derive its slug
  if (head === 'configuration' || head === 'system configuration')
    return '#/configuration/' + slug(segs[segs.length - 1])
  // otherwise the deepest label we recognise wins
  for (let i = segs.length - 2; i >= 0; i--) {
    const k = norm(segs[i])
    if (ROUTES[k])
      return ROUTES[k]
  }
  return null
}

// A menu label: a `backticked` chunk or a short run of capitalized words.
const W = '[A-Z][A-Za-z0-9_-]*'
const WORDS = W + '(?:\\s+(?:and|or|of|the|&amp;)\\s+' + W + '|\\s+' + W + '){0,4}'
const SEG = '(?:`[^`\\n]+`|' + WORDS + ')'
const SEP = '\\s*(?:&gt;|-&gt;|→|»|›)\\s*'
const NAV_RE = new RegExp(SEG + '(?:' + SEP + SEG + '){1,5}', 'g')
const NAV_SEP = /\s*(?:&gt;|-&gt;|→|»|›)\s*/

const navLinks = (s, hold) => s.replace(NAV_RE, m => {
  let text = m, prefix = '', tail = ''
  // sentence punctuation after the last label isn't part of it
  const tm = text.match(/[.,;:!?]+$/)
  if (tm) {
    tail = tm[0]
    text = text.slice(0, -tail.length)
  }
  const segs = text.split(NAV_SEP).map(x => x.trim().replace(/^`+|`+$/g, '').trim()).filter(Boolean)
  if (segs.length < 2)
    return m
  // a capitalized sentence-opening word can glue onto the first label
  // ("Open Configuration > Networks"): drop words until the head is known
  const w = segs[0].split(/\s+/)
  for (let i = 0; i < w.length; i++) {
    const cand = w.slice(i).join(' ')
    if (ROUTES[cand.toLowerCase()]) {
      if (i > 0) {
        prefix = w.slice(0, i).join(' ') + ' '
        segs[0] = cand
      }
      break
    }
  }
  const href = route(segs)
  if (!href)
    return m
  if (prefix.endsWith('`'))
    prefix = prefix.slice(0, -1)
  if (tail.startsWith('`'))
    tail = tail.slice(1)
  hold.push('<a class="navlink" href="' + href + '">' + segs.join(' <span class="navsep">→</span> ') + '</a>')
  return prefix + '\u0002' + (hold.length - 1) + '\u0002' + tail
})

// only MACs get a copy affordance: colon/dash separated, cisco dotted, or bare
export const MAC_RE = /^(?:[0-9A-Fa-f]{2}(?:[:-][0-9A-Fa-f]{2}){5}|[0-9A-Fa-f]{4}(?:\.[0-9A-Fa-f]{4}){2}|[0-9A-Fa-f]{12})$/

// A backticked UI label ("New domain", "REALMS") isn't code.
const isUiLabel = t => {
  if (/[/\\:=<>{}$|]/.test(t))
    return false
  if (/^[A-Z][A-Z0-9]{1,15}$/.test(t))
    return true
  return /\s/.test(t) && !/_/.test(t)
}

export default s => {
  s = esc(s || '')
  const pre = [], hold = []
  s = s.replace(/```\w*\n?([\s\S]*?)```/g, (m, c) => {
    pre.push('<pre><code>' + c.replace(/\n$/, '') + '</code></pre>')
    return '\u0001' + (pre.length - 1) + '\u0001'
  })
  // nav paths first, while their segments are still backticked
  s = navLinks(s, hold)
  s = s.replace(/`([^`\n]+)`/g, (m, c) => {
    const t = c.trim()
    if (MAC_RE.test(t))
      hold.push('<code class="mac" title="click to copy">' + c + '</code>')
    else if (isUiLabel(t))
      hold.push('<span class="uilabel">' + c + '</span>')
    else
      hold.push('<code>' + c + '</code>')
    return '\u0002' + (hold.length - 1) + '\u0002'
  })
  s = s.replace(/\*\*([^*\n]+)\*\*/g, '<strong>$1</strong>')
  s = s.replace(/\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
  s = s.replace(/(?<!["=])(https?:\/\/[^\s<)]+)/g, '<a href="$1" target="_blank" rel="noopener">$1</a>')
  const out = []
  let mode = null, olSeq = 0
  const close = () => {
    if (mode) {
      out.push(mode === 'ol' ? '</ol>' : '</ul>')
      mode = null
    }
  }
  for (const ln of s.split('\n')) {
    let m
    if ((m = ln.match(/^\s*(#{1,4})\s+(.*)/))) {
      close()
      olSeq = 0
      const h = m[1].length + 2 // h3..h6 inside a card
      out.push('<h' + h + '>' + m[2].trim() + '</h' + h + '>')
    }
    // numbered steps interleaved with bullets keep their sequence
    else if ((m = ln.match(/^\s*(\d+)[.)]\s+(.*)/))) {
      const n = parseInt(m[1], 10)
      const num = (n > 1) ? n : (olSeq ? olSeq + 1 : 1)
      olSeq = num
      if (mode !== 'ol') {
        close()
        out.push('<ol start="' + num + '">')
        mode = 'ol'
      }
      out.push('<li>' + m[2] + '</li>')
    }
    else if ((m = ln.match(/^\s*[-*]\s+(.*)/))) {
      if (mode !== 'ul') {
        close()
        out.push('<ul>')
        mode = 'ul'
      }
      out.push('<li>' + m[1] + '</li>')
    }
    else {
      close()
      out.push(ln.trim() === '' ? '\u0000' : '<p>' + ln + '</p>')
    }
  }
  close()
  s = out.join('').replace(/\u0000+/g, '')
  // a held item can contain another placeholder: restore until none remain
  for (let pass = 0; pass < 6 && s.indexOf('\u0002') >= 0; pass++)
    s = s.replace(/\u0002(\d+)\u0002/g, (m, i) => hold[i] !== undefined ? hold[i] : '')
  return s.replace(/<p>\u0001(\d+)\u0001<\/p>|\u0001(\d+)\u0001/g, (m, a, b) => pre[a !== undefined ? a : b])
}
