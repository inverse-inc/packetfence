// k6 baseline: GET /captive-portal with a unique MAC per VU/iteration.
// Measures httpd.portal mod_perl ceiling without exercising registration.
//
// Run examples:
//   k6 run portal_static.js                                 # through haproxy on TARGET default
//   TARGET=http://192.168.126.185 k6 run portal_static.js   # explicit haproxy IP
//   TARGET=http://127.0.0.1:8080  k6 run portal_static.js   # bypass haproxy, hit httpd.portal directly
//   VUS=500 DURATION=2m k6 run portal_static.js             # constant load instead of ramp
//
// Tunables via env:
//   TARGET   base URL (default http://192.168.126.185)
//   HOST     Host header (default packetfence.packetfence.org)
//   VUS      if set, use constant-vus instead of ramp
//   DURATION constant-vus duration (default 2m)

import http from 'k6/http';
import { check } from 'k6';

const TARGET = __ENV.TARGET;
const HOST = __ENV.HOST || 'packetfence.packetfence.org';
if (!TARGET) {
  throw new Error('TARGET env var is required, e.g. TARGET=http://192.168.x.y k6 run portal_static.js');
}

const rampScenario = {
  ramp: {
    executor: 'ramping-vus',
    startVUs: 10,
    stages: [
      { duration: '30s', target: 50 },
      { duration: '1m',  target: 50 },
      { duration: '30s', target: 200 },
      { duration: '2m',  target: 200 },
      { duration: '30s', target: 500 },
      { duration: '2m',  target: 500 },
      { duration: '30s', target: 1000 },
      { duration: '2m',  target: 1000 },
      { duration: '30s', target: 0 },
    ],
    gracefulRampDown: '10s',
  },
};

const constantScenario = {
  constant: {
    executor: 'constant-vus',
    vus: parseInt(__ENV.VUS || '100', 10),
    duration: __ENV.DURATION || '2m',
  },
};

export const options = {
  scenarios: __ENV.VUS ? constantScenario : rampScenario,
  thresholds: {
    http_req_duration: ['p(95)<1000', 'p(99)<2000'],
    http_req_failed: ['rate<0.05'],
    checks: ['rate>0.99'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
  discardResponseBodies: false,
};

// Build a locally-administered MAC from VU + iteration so every request looks
// like a distinct device. 02:00:00:VV:II:II where VV=VU low byte, II=iter.
function macFor(vu, iter) {
  const v = (vu & 0xff).toString(16).padStart(2, '0');
  const a = ((iter >> 8) & 0xff).toString(16).padStart(2, '0');
  const b = (iter & 0xff).toString(16).padStart(2, '0');
  return `02:00:00:${v}:${a}:${b}`;
}

export default function () {
  const mac = macFor(__VU, __ITER);
  const res = http.get(`${TARGET}/captive-portal?mac=${mac}`, {
    headers: { Host: HOST },
    tags: { endpoint: 'portal_get' },
  });

  check(res, {
    'status 200': (r) => r.status === 200,
    'body looks like portal': (r) => r.body && r.body.length > 1000,
  });
}

export function handleSummary(data) {
  const m = data.metrics;
  const dur = m.http_req_duration;
  const reqs = m.http_reqs;
  const lines = [
    '',
    '=== Portal static GET — summary ===',
    `requests:   ${reqs.values.count}  rate=${reqs.values.rate.toFixed(1)}/s`,
    `latency:    avg=${dur.values.avg.toFixed(0)}ms  p50=${dur.values.med.toFixed(0)}ms  p95=${dur.values['p(95)'].toFixed(0)}ms  p99=${dur.values['p(99)'].toFixed(0)}ms  max=${dur.values.max.toFixed(0)}ms`,
    `errors:     ${(m.http_req_failed.values.rate * 100).toFixed(2)}%`,
    `checks:     ${(m.checks.values.rate * 100).toFixed(2)}% passing`,
    '',
  ];
  return { stdout: lines.join('\n') };
}
