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

const appHtml = fs.readFileSync(path.resolve(__dirname, '..', 'index.html'), 'utf8');

function getPermissionHelper() {
  const start = appHtml.indexOf('async function permission(code){');
  const end = appHtml.indexOf('\n}', start);
  return start < 0 || end < 0 ? null : appHtml.slice(start, end + 2);
}

test('Application permission helper fails closed and uses the database permission RPC', () => {
  const helper = getPermissionHelper();
  expect(helper, 'Permission helper should exist').not.toBeNull();
  expect(helper).toContain('if(isSystemAdmin) return true');
  expect(helper).toContain('if(!navigator.onLine) return false');
  expect(helper).toContain('db.rpc("has_permission",{p_permission_code:code})');
  expect(helper).toContain('return data===true');
  expect(helper).toContain('catch (e) { return false; }');
});

test('Trip-load approval and physical dispatch remain separate role actions', () => {
  expect(appHtml).toContain('const approvalRoleAllowed=["SALES_MANAGER","ACCOUNTANT","GENERAL_MANAGER"].includes(currentRoleCode)');
  expect(appHtml).toContain('canApproveTripLoads=isSystemAdmin || (approvalRoleAllowed && await permission("TRIP_LOAD_APPROVE"))');
  expect(appHtml).toContain('canDispatchTripLoads=(currentRoleCode==="WAREHOUSE_KEEPER")');
  expect(appHtml).not.toContain('const approvalRoleAllowed=["SALES_MANAGER","ACCOUNTANT","GENERAL_MANAGER","WAREHOUSE_KEEPER"]');
});

test('Collection viewing, posting and management use separate permission codes', () => {
  expect(appHtml).toContain('canViewCollections=await permission("COLLECTIONS_VIEW") || isSystemAdmin');
  expect(appHtml).toContain('canPostCollections=await permission("COLLECTIONS_POST") || isSystemAdmin');
  expect(appHtml).toContain('canManageCollections=await permission("COLLECTIONS_MANAGE") || isSystemAdmin');
  expect(appHtml).toContain('classList.toggle("hidden",!canViewCollections)');
  expect(appHtml).toContain('classList.toggle("hidden",!canPostCollections)');
});

test('Permission lookup errors do not grant access', () => {
  const helper = getPermissionHelper();
  expect(helper).not.toBeNull();
  expect(helper).toContain('catch (e) { return false; }');
});


function sourceBetween(startMarker, endMarker) {
  const start = appHtml.indexOf(startMarker);
  const end = appHtml.indexOf(endMarker, start);
  return start < 0 || end < 0 ? null : appHtml.slice(start, end);
}

test('General and selected-user notifications are restricted to system administrators', () => {
  const sender = sourceBetween('async function sendManualNotification(){', 'if($("notificationSendAll"))');
  expect(sender, 'Manual notification sender should exist').not.toBeNull();
  expect(sender).toContain('if(!isSystemAdmin)throw new Error("إرسال التنبيهات متاح لمدير النظام فقط.")');
  expect(sender).toContain('const notificationType=sendAll?"GENERAL":"MANUAL"');
  expect(sender).toContain('p_user_ids:users');
  expect(sender).toContain('audience:sendAll?"ALL_ACTIVE_USERS":"SELECTED_USERS"');
});

test('Task notifications are restricted to system administrators and selected recipients', () => {
  const sender = sourceBetween('async function sendTaskNotification(){', 'async function appendReturnInspectionTasks');
  expect(sender, 'Task notification sender should exist').not.toBeNull();
  expect(sender).toContain('if(!isSystemAdmin)throw new Error("إرسال تنبيهات المهام متاح لمدير النظام فقط.")');
  expect(sender).toContain('p_notification_type:"TASK"');
  expect(sender).toContain('p_user_ids:users');
  expect(sender).toContain('audience:"SELECTED_USERS"');
});

test('General notifications and task notifications remain separated in each user inbox', () => {
  const generalInbox = sourceBetween('async function loadNotifications(){', 'async function markAllNotificationsRead(){');
  const taskInbox = sourceBetween('async function loadTaskNotifications(){', 'async function sendTaskNotification(){');
  expect(generalInbox, 'General notification inbox should exist').not.toBeNull();
  expect(taskInbox, 'Task notification inbox should exist').not.toBeNull();
  expect(generalInbox).toContain('.eq("user_id",userId)');
  expect(generalInbox).toContain('notification_type!=="TASK"');
  expect(taskInbox).toContain('.eq("user_id",userId)');
  expect(taskInbox).toContain('notification_type==="TASK"');
});

test('Return inspection requires warehouse review first and a different production reviewer', () => {
  const inspection = sourceBetween('async function appendReturnInspectionTasks(target){', 'async function loadTasks()');
  expect(inspection, 'Return inspection task builder should exist').not.toBeNull();
  expect(inspection).toContain('canInspectReturnsWarehouse && !row.warehouse_inspected_by');
  expect(inspection).toContain('canInspectReturnsProduction && !row.production_inspected_by');
  expect(inspection).toContain('!!row.warehouse_inspected_by && row.warehouse_inspected_by!==currentUserId');
});


test('Return inspection controls require the matching permission and block the previous inspector', () => {
  const inspection = sourceBetween('async function openSalesReturnInspection(ret){', 'async function viewSalesReturn(ret){');
  expect(inspection, 'Return inspection modal should exist').not.toBeNull();
  expect(inspection).toContain('addApproval("WAREHOUSE",canInspectReturnsWarehouse');
  expect(inspection).toContain('addApproval("PRODUCTION",canInspectReturnsProduction');
  expect(inspection).toContain('if(otherInspector&&otherInspector===currentUserId)');
});

test('Return inspection submits the selected stage and validates the full quantity split', () => {
  const inspection = sourceBetween('async function openSalesReturnInspection(ret){', 'async function viewSalesReturn(ret){');
  expect(inspection).not.toBeNull();
  expect(inspection).toContain('p_inspector_type:type');
  expect(inspection).toContain('db.rpc("record_sales_return_item_inspection"');
  expect(inspection).toContain('Math.abs(sv+rv+xv-base)>0.000001');
  expect(inspection).toContain('p_sellable_quantity:sv,p_rework_quantity:rv,p_scrap_quantity:xv');
});

test('Warehouse and production return-inspection permissions remain separate', () => {
  expect(appHtml).toContain('canInspectReturnsWarehouse=await permission("INVENTORY_ADJUST") || isSystemAdmin');
  expect(appHtml).toContain('canInspectReturnsProduction=await permission("PRODUCTION_MANAGE") || isSystemAdmin');
  expect(appHtml).not.toContain('canInspectReturnsProduction=canInspectReturnsWarehouse');
});


const returnInspectionSql = fs.readFileSync(path.resolve(__dirname, '..', 'supabase', 'migrations', '20261116065753_sales_return_joint_inspection_rework.sql'), 'utf8');
const notificationReadSql = fs.readFileSync(path.resolve(__dirname, '..', 'supabase', 'migrations', '20261120132214_block_partner_notification_read_updates_20261120.sql'), 'utf8');
const notificationGrantSql = fs.readFileSync(path.resolve(__dirname, '..', 'supabase', 'migrations', '20261115152852_restrict_notification_recipient_updates_to_read_at.sql'), 'utf8');

test('Database enforces two different users for the two return inspection stages', () => {
  expect(returnInspectionSql).toContain('CHECK(warehouse_inspected_by IS NULL OR production_inspected_by IS NULL OR warehouse_inspected_by<>production_inspected_by)');
  const start = returnInspectionSql.indexOf('CREATE OR REPLACE FUNCTION public.record_sales_return_item_inspection(');
  const end = returnInspectionSql.indexOf('REVOKE ALL ON FUNCTION public.record_sales_return_item_inspection', start);
  const fn = start < 0 || end < 0 ? null : returnInspectionSql.slice(start, end);
  expect(fn, 'Inspection RPC definition should exist').not.toBeNull();
  expect(fn).toContain('SECURITY DEFINER');
  expect(fn).toContain('IF auth.uid() IS NULL');
  expect(fn).toContain("public.has_permission('INVENTORY_ADJUST')");
  expect(fn).toContain("public.has_permission('PRODUCTION_MANAGE')");
  expect(fn).toContain('v_i.production_inspected_by=auth.uid()');
  expect(fn).toContain('v_i.warehouse_inspected_by=auth.uid()');
  expect(fn).toContain('FOR UPDATE');
});

test('Return inspection RPC is not executable by public or anonymous users', () => {
  expect(returnInspectionSql).toContain('REVOKE ALL ON FUNCTION public.record_sales_return_item_inspection(bigint,text,text,text,numeric,numeric,numeric) FROM PUBLIC,anon');
  expect(returnInspectionSql).toContain('GRANT EXECUTE ON FUNCTION public.record_sales_return_item_inspection(bigint,text,text,text,numeric,numeric,numeric) TO authenticated');
});

test('Notification recipients can only update their read timestamp through table grants', () => {
  expect(notificationGrantSql).toContain('REVOKE UPDATE ON TABLE public.notification_recipients FROM authenticated');
  expect(notificationGrantSql).toContain('GRANT UPDATE (read_at) ON TABLE public.notification_recipients TO authenticated');
});

test('Marking a notification read is limited to its recipient and blocks partner accounts', () => {
  expect(notificationReadSql).toContain("IF auth.uid() IS NULL THEN");
  expect(notificationReadSql).toContain("IF public.get_current_user_role() = 'PARTNER' THEN");
  expect(notificationReadSql).toContain('WHERE notification_id = p_notification_id');
  expect(notificationReadSql).toContain('AND user_id = auth.uid()');
});
