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
  ['cluster/restartSystemService', 'packetfence-config', 'Failed to restart packetfence-config'],
  ['cluster/updateSystemd', 'pf', 'Failed to update systemd'],
  ['cluster/restartService', 'pfperl-api', 'Failed to restart pfperl-api'],
  ['cluster/restartService', 'haproxy-admin', 'Failed to restart haproxy-admin'],
  ['cluster/startService', 'pf', 'Failed to start packetfence services'],
  ['cluster/completeConfigurator', undefined, 'Failed to complete configuration']
]

function fixture (failAt = -1) {
  const calls = []
  const timers = []
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
      return {}
    }
  } } })
  return { state, calls, timers, context }
}

for (let failAt = 0; failAt < steps.length; failAt++) {
  test(`wizard stops when ${steps[failAt][0]} ${steps[failAt][1] || ''} fails`, async () => {
    const { state, calls, timers, context } = fixture(failAt)
    await state.onComplete()
    assert.deepEqual(calls.map(([action, payload]) => [action, payload && payload.id]),
      steps.slice(0, failAt + 1).map(([action, id]) => [action, id]))
    assert.equal(state.invalidFeedback.value, steps[failAt][2])
    assert.equal(state.progressFeedback.value, null)
    assert.equal(state.isLoading.value, false)
    assert.equal(timers.length, 0, 'failed completion does not schedule a redirect')
    assert.equal(context.window.location.href, '/configurator/status')
  })
}

test('wizard requests completion only after all service steps succeed', async () => {
  const { state, calls, timers, context } = fixture()
  await state.onComplete()
  assert.deepEqual(calls.map(([action, payload]) => [action, payload && payload.id]),
    steps.map(([action, id]) => [action, id]))
  assert.equal(state.invalidFeedback.value, null)
  assert.equal(state.isLoading.value, false)
  assert.equal(timers.length, 1)
  timers[0]()
  assert.equal(context.window.location.href, '/')
})
