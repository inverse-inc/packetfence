const fs = require('fs-extra');
const fetch = require('node-fetch');
const base = require('./cypress.config.js');

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
          await fs.writeFile('../fixtures/runtime/maintenanceTasks.json', JSON.stringify(items.map(item => item.id), null, 2));
          await items.forEach(async item => {
            await fs.writeFile(`../fixtures/runtime/maintenanceTask-${item.id}.json`, JSON.stringify(item, null, 2));
          })
        })
      });
      return base.e2e.setupNodeEvents(on, config);
    },

    specPattern: [
      'cypress/specs/e2e/*-views/20*.cy.{js,jsx,ts,tsx}',
//      'cypress/specs/e2e/*-views/**/*.cy.{js,jsx,ts,tsx}',
    ],
  }
};
