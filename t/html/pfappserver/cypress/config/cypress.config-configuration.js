const fs = require('fs-extra');
const fetch = require('node-fetch');
const path = require('path');
const base = require('./cypress.config.js');
const fixturesPath = path.join(__dirname, '../fixtures');

module.exports = {
  ...base,

  e2e: {
    ...base.e2e,

    setupNodeEvents: (on, config) => {
      on('before:run', async (details) => {
        await fs.readFile('/usr/local/pf/conf/unified_api_system_pass', 'utf-8', async (err, password) => {
          // login, get auth token
          let request = JSON.stringify({ username: 'system', password: password.trim() });
          let response = await fetch(`${base.e2e.baseUrl}/api/v1/login`, { method: 'POST', body: request });
          let body = await response.text();
          let { token } = JSON.parse(body);
          let headers = { 'Authorization': `Bearer ${token}` };

          // get maintenance tasks, write fixtures
          response = await fetch(`${base.e2e.baseUrl}/api/v1/config/maintenance_tasks?limit=1000`, { method: 'GET', headers });
          body = await response.text();
          let { items = [] } = JSON.parse(body);
          await fs.writeJson(`${fixturesPath}/runtime/maintenanceTasks.json`, items.map(item => item.id), { spaces: '\t' });
          await items.forEach(async item => {
            await fs.writeJson(`${fixturesPath}/runtime/maintenanceTask-${item.id}.json`, item, { spaces: '\t' });
          })

          // get ACLs, write fixtures
          response = await fetch(`${base.e2e.baseUrl}/api/v1/config/admin_roles`, { method: 'OPTIONS', headers });
          body = await response.text();
          let { meta: { actions: { item: { allowed = [] } = {} } = {} } = {} } = JSON.parse(body);
          let acls = allowed.reduce((acls, { options }) => {
            options.forEach(({ text, value }) => {
              acls[value] = text
            })
            return acls
          }, {})
          await fs.writeJson(`${fixturesPath}/runtime/acls.json`, acls, { spaces: '\t' });
        })
      });
      return base.e2e.setupNodeEvents(on, config);
    },

    defaultCommandTimeout: 60E3,
    requestTimeout: 60E3,
    specPattern: [
      'cypress/specs/e2e/*-configuration/**/*.cy.{js,jsx,ts,tsx}',
    ],
  },
};
