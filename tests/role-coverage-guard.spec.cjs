const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');

const roleSpec = fs.readFileSync(path.resolve(__dirname, 'role-coverage.spec.cjs'), 'utf8');

const expectedRoles = [
  'SYSTEM_ADMIN',
  'SALES_MANAGER',
  'SALES_REP',
  'WAREHOUSE_KEEPER',
  'PRODUCTION_MANAGER',
  'ACCOUNTANT',
  'GENERAL_MANAGER'
];

test('Role coverage defines seven independent role identities', () => {
  const roleBlock = roleSpec.match(/const roles = \[([\s\S]*?)\n\];/);
  expect(roleBlock, 'Role list should exist').not.toBeNull();

  const configuredRoles = [...roleBlock[1].matchAll(/code: '([A-Z_]+)'/g)].map(match => match[1]);
  expect(configuredRoles).toEqual(expectedRoles);
  expect(new Set(configuredRoles).size).toBe(7);
});

for (const role of expectedRoles) {
  test('Role coverage uses dedicated credentials for ' + role, () => {
    expect(roleSpec).toContain("code: '" + role + "'");
    expect(roleSpec).toContain('QA_' + role + '_USERNAME');
    expect(roleSpec).toContain('QA_' + role + '_PASSWORD');
  });
}

test('Role coverage skips safely when the isolated environment is not enabled', () => {
  expect(roleSpec).toContain("process.env.QA_ROLE_TESTS_SAFE_ENVIRONMENT !== 'true'");
  expect(roleSpec).toContain('QA_SUPABASE_URL and QA_SUPABASE_ANON_KEY must point to a separate test project.');
});

test('Role coverage blocks the production Supabase URL', () => {
  expect(roleSpec).toContain("qaSupabaseUrl === productionSupabaseUrl");
  expect(roleSpec).toContain('role login tests cannot use the production Supabase project.');
});

test('Role coverage verifies the actual database role instead of trusting the requested role', () => {
  expect(roleSpec).toContain("responseUrl.pathname.endsWith('/rest/v1/app_roles')");
  expect(roleSpec).toContain('}).toBe(role.code)');
});

test('Role coverage never falls back to the shared production smoke-test account', () => {
  expect(roleSpec).not.toContain('process.env.TEST_USERNAME');
  expect(roleSpec).not.toContain('process.env.TEST_PASSWORD');
});
