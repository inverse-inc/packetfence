// Run with: node --test t/html/pfappserver/configurator-completion.test.js
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const { test } = require('node:test')

// Exercise the real component setup with only Vue refs, translations and store I/O stubbed.
const component = fs.readFileSync(path.resolve(__dirname,
  '../../../html/pfappserver/root/src/views/Configurator/status/_components/TheStep.vue'), 'utf8')
const script = component.match(/<script>([\s\S]*?)<\/script>/)[1]
  .replace(/^import .*$/gm, '')
  .replace(/export default/, 'globalThis.component =')

const steps = [
  ['$_bases/getAdvanced', undefined, 'Failed to load advanced configuration'],
  ['cluster/restartSystemService', 'packetfence-config', 'Failed to restart packetfence-config'],
  ['cluster/updateSystemd', 'pf', 'Failed to update systemd'],
  ['cluster/restartService', 'pfperl-api', 'Failed to restart pfperl-api'],
  ['cluster/restartService', 'haproxy-admin', 'Failed to restart haproxy-admin'],
  ['cluster/startService', 'pf', 'Failed to start packetfence services'],
  ['$_bases/updateAdvanced', undefined, 'Failed to update advanced']
]

function fixture (failAt = -1) {
  const calls = []
  const timers = []
  const advanced = { configurator: 'enabled', other: 'preserved' }
  const context = vm.createContext({
    i18n: { t: text => text },
    BaseButtonSave: {}, BaseStep: {}, FormStatus: {},
    ref: value => ({ value }),
    window: { location: { href: '/configurator/status' } },
    setTimeout: callback => timers.push(callback)
  })
  vm.runInContext(script, context)
  const state = context.component.setup({}, { root: { $store: {
    dispatch: async (action, payload) => {
      const index = calls.length
      calls.push([action, payload])
      if (index === failAt) throw new Error('Injected failure')
      return action === '$_bases/getAdvanced' ? advanced : {}
    }
  } } })
  return { state, calls, timers, advanced, context }
}

for (let failAt = 0; failAt < steps.length; failAt++) {
  test(`wizard stops when ${steps[failAt][0]} ${steps[failAt][1] || ''} fails`, async () => {
    const { state, calls, timers, advanced, context } = fixture(failAt)
    await state.onComplete()
    assert.deepEqual(calls.map(([action, payload]) => [action, payload && payload.id]),
      steps.slice(0, failAt + 1).map(([action, id]) => [action, id]))
    assert.equal(state.invalidFeedback.value, steps[failAt][2])
    assert.equal(state.progressFeedback.value, null)
    assert.equal(state.isLoading.value, false)
    assert.equal(advanced.configurator, 'enabled', 'cached configuration is not mutated')
    assert.equal(timers.length, 0, 'failed completion does not schedule a redirect')
    assert.equal(context.window.location.href, '/configurator/status')
  })
}

test('successful wizard completion disables the configurator only after all service steps', async () => {
  const { state, calls, timers, advanced, context } = fixture()
  await state.onComplete()
  assert.deepEqual(calls.map(([action, payload]) => [action, payload && payload.id]),
    steps.map(([action, id]) => [action, id]))
  assert.equal(calls.at(-1)[1].configurator, 'disabled')
  assert.equal(calls.at(-1)[1].other, 'preserved')
  assert.equal(advanced.configurator, 'enabled')
  assert.equal(state.invalidFeedback.value, null)
  assert.equal(state.isLoading.value, false)
  assert.equal(timers.length, 1)
  timers[0]()
  assert.equal(context.window.location.href, '/')
})
