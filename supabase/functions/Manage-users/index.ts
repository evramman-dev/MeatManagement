
import { createClient } from "npm:@supabase/supabase-js@2";

const APP_ORIGIN = "https://evramman-dev.github.io";

const ALLOWED_ROLES = [
  "SALES_MANAGER",
  "SALES_REP",
  "WAREHOUSE_KEEPER",
  "PRODUCTION_MANAGER",
  "ACCOUNTANT",
  "GENERAL_MANAGER",
  "SYSTEM_TESTER",
  "PARTNER",
];

const corsHeaders = {
  "Access-Control-Allow-Origin": APP_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function respond(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

function cleanError(error: unknown): string {
  if (error && typeof error === "object" && "message" in error) {
    return String((error as { message: unknown }).message);
  }
  return "حدث خطأ غير متوقع.";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return respond({ success: false, error: "طريقة الطلب غير مسموح بها." }, 405);
  }

  const origin = req.headers.get("origin");
  if (origin && origin !== APP_ORIGIN) {
    return respond({ success: false, error: "مصدر الطلب غير مسموح به." }, 403);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return respond({
      success: false,
      error: "إعدادات Supabase المطلوبة غير مكتملة.",
    }, 500);
  }

  const authorization = req.headers.get("authorization") || "";
  const tokenMatch = authorization.match(/^Bearer\s+(.+)$/i);

  if (!tokenMatch) {
    return respond({ success: false, error: "يجب تسجيل الدخول أولًا." }, 401);
  }

  const token = tokenMatch[1];

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  // التحقق من هوية الشخص الذي يطلب إنشاء الحساب.
  const { data: callerData, error: callerError } =
    await admin.auth.getUser(token);

  if (callerError || !callerData.user) {
    return respond({ success: false, error: "جلسة الدخول غير صالحة." }, 401);
  }

  const callerId = callerData.user.id;

  const { data: callerProfile, error: profileError } = await admin
    .from("app_users")
    .select("user_id, is_active, role_id")
    .eq("user_id", callerId)
    .maybeSingle();

  if (profileError) {
    return respond({
      success: false,
      error: "تعذر التحقق من صلاحيات مدير النظام.",
    }, 500);
  }

  if (!callerProfile || callerProfile.is_active !== true) {
    return respond({
      success: false,
      error: "الحساب غير مسجل في النظام أو غير مفعّل.",
    }, 403);
  }

  const { data: callerRole, error: callerRoleError } = await admin
    .from("app_roles")
    .select("role_code, is_active")
    .eq("role_id", callerProfile.role_id)
    .maybeSingle();

  if (
    callerRoleError ||
    !callerRole ||
    callerRole.is_active !== true ||
    callerRole.role_code !== "SYSTEM_ADMIN"
  ) {
    return respond({
      success: false,
      error: "إنشاء حسابات الموظفين متاح لمدير النظام فقط.",
    }, 403);
  }

  let body: Record<string, unknown>;

  try {
    body = await req.json();
  } catch {
    return respond({ success: false, error: "بيانات الطلب غير صالحة." }, 400);
  }
  // ربط حساب PARTNER بسجل شريك واحد، بعد التحقق من الدور والحالة وعدم وجود ربط سابق.
  if (body.action === "link_partner") {
    const targetUserId = typeof body.target_user_id === "string" ? body.target_user_id.trim() : "";
    const partnerId = Number(body.partner_id);
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(targetUserId)) {
      return respond({ success: false, error: "معرف حساب الشريك غير صالح." }, 400);
    }
    if (!Number.isSafeInteger(partnerId) || partnerId <= 0) {
      return respond({ success: false, error: "سجل الشريك المحدد غير صالح." }, 400);
    }
    const { data: targetProfile, error: targetProfileError } = await admin
      .from("app_users")
      .select("user_id, role_id, partner_id, is_active")
      .eq("user_id", targetUserId)
      .maybeSingle();
    if (targetProfileError || !targetProfile) {
      return respond({ success: false, error: "تعذر العثور على حساب المستخدم المطلوب." }, 404);
    }
    const { data: targetRole, error: targetRoleError } = await admin
      .from("app_roles")
      .select("role_code, is_active")
      .eq("role_id", targetProfile.role_id)
      .maybeSingle();
    if (targetRoleError || !targetRole || targetRole.role_code !== "PARTNER" || targetRole.is_active !== true) {
      return respond({ success: false, error: "يمكن ربط سجل شريك بحساب يحمل دور الشريك النشط فقط." }, 400);
    }
    if (targetProfile.partner_id !== null && Number(targetProfile.partner_id) !== partnerId) {
      return respond({ success: false, error: "هذا الحساب مرتبط بالفعل بسجل شريك آخر." }, 409);
    }
    const { data: partner, error: partnerError } = await admin
      .from("partners")
      .select("partner_id, is_active")
      .eq("partner_id", partnerId)
      .maybeSingle();
    if (partnerError || !partner || partner.is_active !== true) {
      return respond({ success: false, error: "سجل الشريك غير موجود أو غير نشط." }, 404);
    }
    const { data: linkedUsers, error: linkedUsersError } = await admin
      .from("app_users")
      .select("user_id")
      .eq("partner_id", partnerId)
      .neq("user_id", targetUserId)
      .limit(1);
    if (linkedUsersError) {
      return respond({ success: false, error: "تعذر التحقق من ارتباط سجل الشريك." }, 500);
    }
    if (linkedUsers && linkedUsers.length > 0) {
      return respond({ success: false, error: "سجل الشريك مرتبط بالفعل بحساب مستخدم آخر." }, 409);
    }
    const { error: linkError } = await admin
      .from("app_users")
      .update({ partner_id: partnerId })
      .eq("user_id", targetUserId)
      .is("partner_id", null);
    if (linkError) {
      return respond({ success: false, error: "تعذر حفظ ربط حساب الشريك: " + cleanError(linkError) }, 500);
    }
    return respond({ success: true, message: "تم ربط حساب الشريك بسجله بنجاح." });
  }

  // حذف حساب مختبر النظام فقط. لا يحذف أي حركات أو بيانات تشغيلية أنشأها الحساب.
  if (body.action === "delete_tester") {
    const targetUserId =
      typeof body.target_user_id === "string" ? body.target_user_id.trim() : "";

    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(targetUserId)) {
      return respond({ success: false, error: "معرف حساب المختبر غير صالح." }, 400);
    }

    if (targetUserId === callerId) {
      return respond({ success: false, error: "لا يمكن حذف الحساب المستخدم حاليًا." }, 400);
    }

    const { data: targetProfile, error: targetProfileError } = await admin
      .from("app_users")
      .select("user_id, role_id, username, display_name, is_active")
      .eq("user_id", targetUserId)
      .maybeSingle();

    if (targetProfileError) {
      return respond({ success: false, error: "تعذر التحقق من حساب المختبر." }, 500);
    }

    if (!targetProfile) {
      return respond({ success: false, error: "حساب المختبر غير موجود." }, 404);
    }

    const { data: targetRole, error: targetRoleError } = await admin
      .from("app_roles")
      .select("role_code")
      .eq("role_id", targetProfile.role_id)
      .maybeSingle();

    if (targetRoleError) {
      return respond({ success: false, error: "تعذر التحقق من دور الحساب المطلوب." }, 500);
    }

    if (!targetRole || targetRole.role_code !== "SYSTEM_TESTER") {
      return respond({ success: false, error: "الحذف متاح لحساب مختبر النظام فقط." }, 403);
    }

    const { error: authDeleteError } = await admin.auth.admin.deleteUser(targetUserId);

    if (authDeleteError) {
      console.error("Tester Auth deletion failed:", authDeleteError.message);
      return respond({ success: false, error: "تعذر حذف حساب تسجيل الدخول للمختبر." }, 500);
    }

    const { error: profileDeleteError } = await admin
      .from("app_users")
      .delete()
      .eq("user_id", targetUserId);

    if (profileDeleteError) {
      console.error("Tester profile cleanup failed:", profileDeleteError.message);
      return respond({
        success: false,
        error: "تم إلغاء حساب الدخول، لكن تعذر حذف ملف المستخدم الداخلي. يلزم تنظيف هذا السجل من قاعدة البيانات.",
      }, 500);
    }

    return respond({
      success: true,
      message: "تم حذف حساب مختبر النظام. لم يتم حذف الحركات أو البيانات التي أنشأها.",
    });
  }

  // إجراء مؤقت لإعادة تعيين كلمة مرور Rep-01 فقط.
  if (body.action === "reset_password") {
    const newPassword =
      typeof body.password === "string" ? body.password : "";

    if (newPassword.length < 12 || newPassword.length > 128) {
      return respond({
        success: false,
        error: "كلمة المرور يجب أن تتراوح بين 12 و128 حرفًا.",
      }, 400);
    }

    const { data: targetUser, error: targetError } = await admin
      .from("app_users")
      .select("user_id, username, is_active")
      .eq("username", "Rep-01")
      .maybeSingle();

    if (targetError) {
      return respond({
        success: false,
        error: "تعذر العثور على حساب Rep-01.",
      }, 500);
    }

    if (!targetUser || targetUser.is_active !== true) {
      return respond({
        success: false,
        error: "حساب Rep-01 غير موجود أو غير نشط.",
      }, 404);
    }

    const { data: updatedUser, error: updateError } =
      await admin.auth.admin.updateUserById(
        targetUser.user_id,
        { password: newPassword }
      );

    if (updateError || !updatedUser.user) {
      console.error(
        "Password reset failed:",
        updateError?.message
      );

      return respond({
        success: false,
        error: "تعذر تغيير كلمة مرور Rep-01.",
      }, 500);
    }

    return respond({
      success: true,
      message: "تم تغيير كلمة مرور Rep-01 بنجاح.",
    });
  }
  const displayName =
    typeof body.display_name === "string" ? body.display_name.trim() : "";

  const username =
    typeof body.username === "string" ? body.username.trim() : "";

  const password =
    typeof body.password === "string" ? body.password : "";

  const roleId = Number(body.role_id);

  const salesRepId =
    body.sales_rep_id === null ||
    body.sales_rep_id === undefined ||
    body.sales_rep_id === ""
      ? null
      : Number(body.sales_rep_id);

  if (displayName.length < 2 || displayName.length > 120) {
    return respond({
      success: false,
      error: "اسم الموظف يجب أن يكون من حرفين إلى 120 حرفًا.",
    }, 400);
  }

  if (!/^[A-Za-z0-9._-]{3,32}$/.test(username)) {
    return respond({
      success: false,
      error:
        "اسم المستخدم يجب أن يكون من 3 إلى 32 حرفًا، باستخدام الإنجليزية أو الأرقام أو النقطة أو الشرطة أو الشرطة السفلية فقط.",
    }, 400);
  }

  if (password.length < 12 || password.length > 128) {
    return respond({
      success: false,
      error: "كلمة المرور يجب أن تتراوح بين 12 و128 حرفًا.",
    }, 400);
  }

  if (!Number.isSafeInteger(roleId) || roleId <= 0) {
    return respond({ success: false, error: "الدور الوظيفي غير صالح." }, 400);
  }

  // التأكد من أن الدور المطلوب نشط ومسموح بإنشائه من هذه الواجهة.
  const { data: targetRole, error: targetRoleError } = await admin
    .from("app_roles")
    .select("role_id, role_code, is_active")
    .eq("role_id", roleId)
    .maybeSingle();

  if (targetRoleError) {
    return respond({
      success: false,
      error: "تعذر التحقق من الدور الوظيفي.",
    }, 500);
  }

  if (
    !targetRole ||
    targetRole.is_active !== true ||
    !ALLOWED_ROLES.includes(targetRole.role_code)
  ) {
    return respond({
      success: false,
      error: "الدور الوظيفي غير نشط أو غير مسموح بإنشائه.",
    }, 400);
  }

  if (targetRole.role_code === "SALES_REP") {
    if (!Number.isSafeInteger(salesRepId) || salesRepId === null || salesRepId <= 0) {
      return respond({
        success: false,
        error: "يجب اختيار سجل مندوب المبيعات المراد ربطه بالحساب.",
      }, 400);
    }
  } else if (salesRepId !== null) {
    return respond({
      success: false,
      error: "ربط سجل مندوب مطلوب فقط لحساب مندوب المبيعات.",
    }, 400);
  }

  // التحقق من اسم المستخدم قبل إنشاء حساب Auth.
  const { data: existingUsername, error: usernameCheckError } = await admin
    .from("app_users")
    .select("user_id")
    .ilike("username", username)
    .limit(1);

  if (usernameCheckError) {
    return respond({
      success: false,
      error: "تعذر التحقق من اسم المستخدم.",
    }, 500);
  }

  if (existingUsername && existingUsername.length > 0) {
    return respond({
      success: false,
      error: "اسم المستخدم مستخدم بالفعل. اختر اسمًا آخر.",
    }, 409);
  }

  // التأكد من أن سجل المندوب موجود ونشط وغير مرتبط بحساب آخر.
  if (targetRole.role_code === "SALES_REP") {
    const { data: rep, error: repError } = await admin
      .from("sales_reps")
      .select("sales_rep_id, is_active, auth_user_id")
      .eq("sales_rep_id", salesRepId)
      .maybeSingle();

    if (repError) {
      return respond({
        success: false,
        error: "تعذر التحقق من سجل مندوب المبيعات.",
      }, 500);
    }

    if (!rep || rep.is_active !== true || rep.auth_user_id !== null) {
      return respond({
        success: false,
        error: "المندوب غير نشط أو مرتبط بالفعل بحساب دخول.",
      }, 409);
    }

    const { data: linkedUser, error: linkedUserError } = await admin
      .from("app_users")
      .select("user_id")
      .eq("sales_rep_id", salesRepId)
      .limit(1);

    if (linkedUserError) {
      return respond({
        success: false,
        error: "تعذر التحقق من ارتباط المندوب بحساب آخر.",
      }, 500);
    }

    if (linkedUser && linkedUser.length > 0) {
      return respond({
        success: false,
        error: "المندوب مرتبط بالفعل بحساب مستخدم.",
      }, 409);
    }
  }

  // إنشاء بريد داخلي اصطناعي لا يحتاج الموظف إلى امتلاكه.
  // نطاق .invalid محجوز ولا يُستخدم كبريد حقيقي.
  const internalEmail =
    `employee-${crypto.randomUUID()}@accounts.meatmanagement.invalid`;

  let createdUserId: string | null = null;
  let appUserInserted = false;
  let salesRepLinked = false;

  try {
    const { data: authData, error: authError } =
      await admin.auth.admin.createUser({
        email: internalEmail,
        password,
        email_confirm: true,
        user_metadata: {
          display_name: displayName,
          username,
        },
      });

    if (authError || !authData.user) {
      throw new Error(
        authError ? cleanError(authError) : "تعذر إنشاء حساب تسجيل الدخول."
      );
    }

    createdUserId = authData.user.id;

    // حفظ اسم المستخدم في نفس عملية إنشاء ملف الموظف.
    const { error: appUserError } = await admin
      .from("app_users")
      .insert({
        user_id: createdUserId,
        role_id: roleId,
        display_name: displayName,
        username,
        sales_rep_id: salesRepId,
        is_active: true,
      });

    if (appUserError) {
      if (appUserError.code === "23505") {
        throw new Error("اسم المستخدم مستخدم بالفعل. اختر اسمًا آخر.");
      }
      throw new Error(
        "تعذر حفظ ملف الموظف: " + cleanError(appUserError)
      );
    }

    appUserInserted = true;

    if (targetRole.role_code === "SALES_REP" && salesRepId !== null) {
      const { data: updatedRep, error: linkError } = await admin
        .from("sales_reps")
        .update({ auth_user_id: createdUserId })
        .eq("sales_rep_id", salesRepId)
        .is("auth_user_id", null)
        .select("sales_rep_id")
        .maybeSingle();

      if (linkError || !updatedRep) {
        throw new Error(
          linkError
            ? "تعذر ربط حساب الموظف بسجل المندوب: " + cleanError(linkError)
            : "لم يتم ربط المندوب؛ ربما تم ربطه بحساب آخر أثناء العملية."
        );
      }

      salesRepLinked = true;
    }

    return respond({
      success: true,
      message: "تم إنشاء حساب الموظف وحفظ اسم المستخدم بنجاح.",
      user: {
        user_id: createdUserId,
        username,
        display_name: displayName,
        role_code: targetRole.role_code,
        sales_rep_id: salesRepId,
      },
    });
  } catch (error) {
    // محاولة التراجع عن أي خطوات تمت قبل الفشل.
    const rollbackErrors: string[] = [];

    if (createdUserId && salesRepLinked && salesRepId !== null) {
      const { error: unlinkError } = await admin
        .from("sales_reps")
        .update({ auth_user_id: null })
        .eq("sales_rep_id", salesRepId)
        .eq("auth_user_id", createdUserId);

      if (unlinkError) {
        rollbackErrors.push("تعذر فك ارتباط المندوب.");
      }
    }

    if (createdUserId && appUserInserted) {
      const { error: deleteProfileError } = await admin
        .from("app_users")
        .delete()
        .eq("user_id", createdUserId);

      if (deleteProfileError) {
        rollbackErrors.push("تعذر حذف سجل الموظف الذي لم يكتمل إنشاؤه.");
      }
    }

    if (createdUserId) {
      const { error: deleteAuthError } =
        await admin.auth.admin.deleteUser(createdUserId);

      if (deleteAuthError) {
        rollbackErrors.push("تعذر حذف حساب تسجيل الدخول الذي لم يكتمل إنشاؤه.");
      }
    }

    const baseMessage = cleanError(error);

    return respond({
      success: false,
      error: rollbackErrors.length
        ? `${baseMessage} تنبيه: لم يكتمل التراجع عن جميع الخطوات؛ راجع البيانات قبل إعادة المحاولة. ${rollbackErrors.join(" ")}`
        : baseMessage,
    }, 400);
  }
});
