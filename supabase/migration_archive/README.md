# أرشيف ملفات ترحيل غير مطابقة

هذه الملفات محفوظة لأغراض المراجعة والتوثيق فقط. لا تضعها داخل `supabase/migrations` ولا تشغّلها على قاعدة البيانات.

تم نقلها من مجلد الترحيلات التنفيذية لأن رقم كل ملف لا يظهر في سجل Supabase. فحصنا آثار التغييرات الأساسية في الدوال الحالية، لكن لا يمكن استنتاج رقم الترحيل الأصلي أو إثبات تطابق SQL حرفيًا من سجل Supabase وحده.

الملفات:
- `20261114220000_fix_customer_receivables_summary.sql`
- `20261114224500_guard_closed_trip_cash_reversals.sql`
- `20261116090000_fix_sales_return_cancel_full_received_quantity.sql`

راجع `supabase/MIGRATION_HISTORY.md` قبل أي محاولة لإعادة بناء قاعدة البيانات.
