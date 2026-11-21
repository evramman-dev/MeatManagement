export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      accounting_period_closures: {
        Row: {
          closing_entry_id: number | null
          closure_id: number
          cogs_amount: number
          created_at: string
          created_by: string
          expenses_amount: number
          period_id: number
          profit_amount: number
          request_id: string
          revenue_amount: number
        }
        Insert: {
          closing_entry_id?: number | null
          closure_id?: number
          cogs_amount?: number
          created_at?: string
          created_by: string
          expenses_amount?: number
          period_id: number
          profit_amount?: number
          request_id: string
          revenue_amount?: number
        }
        Update: {
          closing_entry_id?: number | null
          closure_id?: number
          cogs_amount?: number
          created_at?: string
          created_by?: string
          expenses_amount?: number
          period_id?: number
          profit_amount?: number
          request_id?: string
          revenue_amount?: number
        }
        Relationships: [
          {
            foreignKeyName: "accounting_period_closures_closing_entry_id_fkey"
            columns: ["closing_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["entry_id"]
          },
          {
            foreignKeyName: "accounting_period_closures_period_id_fkey"
            columns: ["period_id"]
            isOneToOne: true
            referencedRelation: "accounting_periods"
            referencedColumns: ["period_id"]
          },
        ]
      }
      accounting_periods: {
        Row: {
          closed_at: string | null
          closed_by: string | null
          created_at: string
          created_by: string | null
          end_date: string
          notes: string | null
          period_id: number
          period_name: string
          start_date: string
          status: string
        }
        Insert: {
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          created_by?: string | null
          end_date: string
          notes?: string | null
          period_id?: number
          period_name: string
          start_date: string
          status?: string
        }
        Update: {
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          created_by?: string | null
          end_date?: string
          notes?: string | null
          period_id?: number
          period_name?: string
          start_date?: string
          status?: string
        }
        Relationships: []
      }
      app_permissions: {
        Row: {
          created_at: string
          is_active: boolean
          permission_code: string
          permission_id: number
          permission_name: string
        }
        Insert: {
          created_at?: string
          is_active?: boolean
          permission_code: string
          permission_id?: never
          permission_name: string
        }
        Update: {
          created_at?: string
          is_active?: boolean
          permission_code?: string
          permission_id?: never
          permission_name?: string
        }
        Relationships: []
      }
      app_role_permissions: {
        Row: {
          created_at: string
          permission_id: number
          role_id: number
        }
        Insert: {
          created_at?: string
          permission_id: number
          role_id: number
        }
        Update: {
          created_at?: string
          permission_id?: number
          role_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "app_role_permissions_permission_id_fkey"
            columns: ["permission_id"]
            isOneToOne: false
            referencedRelation: "app_permissions"
            referencedColumns: ["permission_id"]
          },
          {
            foreignKeyName: "app_role_permissions_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "app_roles"
            referencedColumns: ["role_id"]
          },
        ]
      }
      app_roles: {
        Row: {
          created_at: string
          is_active: boolean
          role_code: string
          role_id: number
          role_name: string
        }
        Insert: {
          created_at?: string
          is_active?: boolean
          role_code: string
          role_id?: never
          role_name: string
        }
        Update: {
          created_at?: string
          is_active?: boolean
          role_code?: string
          role_id?: never
          role_name?: string
        }
        Relationships: []
      }
      app_users: {
        Row: {
          created_at: string
          display_name: string
          is_active: boolean
          last_login: string | null
          partner_id: number | null
          role_id: number
          sales_rep_id: number | null
          updated_at: string
          user_id: string
          username: string | null
        }
        Insert: {
          created_at?: string
          display_name: string
          is_active?: boolean
          last_login?: string | null
          partner_id?: number | null
          role_id: number
          sales_rep_id?: number | null
          updated_at?: string
          user_id: string
          username?: string | null
        }
        Update: {
          created_at?: string
          display_name?: string
          is_active?: boolean
          last_login?: string | null
          partner_id?: number | null
          role_id?: number
          sales_rep_id?: number | null
          updated_at?: string
          user_id?: string
          username?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "app_users_partner_id_fkey"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["partner_id"]
          },
          {
            foreignKeyName: "app_users_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "app_roles"
            referencedColumns: ["role_id"]
          },
          {
            foreignKeyName: "app_users_sales_rep_id_fkey"
            columns: ["sales_rep_id"]
            isOneToOne: false
            referencedRelation: "sales_reps"
            referencedColumns: ["sales_rep_id"]
          },
        ]
      }
      areas: {
        Row: {
          area_id: number
          area_type: string
          city_id: number
          created_at: string
          is_active: boolean
          name: string
          updated_at: string
        }
        Insert: {
          area_id?: number
          area_type?: string
          city_id: number
          created_at?: string
          is_active?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          area_id?: number
          area_type?: string
          city_id?: number
          created_at?: string
          is_active?: boolean
          name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "areas_city_fk"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["city_id"]
          },
        ]
      }
      chart_of_accounts: {
        Row: {
          account_code: string
          account_id: number
          account_name: string
          account_type: string
          is_active: boolean
          parent_id: number | null
        }
        Insert: {
          account_code: string
          account_id?: number
          account_name: string
          account_type: string
          is_active?: boolean
          parent_id?: number | null
        }
        Update: {
          account_code?: string
          account_id?: number
          account_name?: string
          account_type?: string
          is_active?: boolean
          parent_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "chart_of_accounts_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["account_id"]
          },
        ]
      }
      cities: {
        Row: {
          city_id: number
          created_at: string
          governorate_id: number
          is_active: boolean
          name: string
          unit_type: string
          updated_at: string
        }
        Insert: {
          city_id?: number
          created_at?: string
          governorate_id: number
          is_active?: boolean
          name: string
          unit_type?: string
          updated_at?: string
        }
        Update: {
          city_id?: number
          created_at?: string
          governorate_id?: number
          is_active?: boolean
          name?: string
          unit_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "cities_governorate_fk"
            columns: ["governorate_id"]
            isOneToOne: false
            referencedRelation: "governorates"
            referencedColumns: ["governorate_id"]
          },
        ]
      }
      company_settings: {
        Row: {
          setting_key: string
          setting_value: string | null
        }
        Insert: {
          setting_key: string
          setting_value?: string | null
        }
        Update: {
          setting_key?: string
          setting_value?: string | null
        }
        Relationships: []
      }
      customer_cheques: {
        Row: {
          amount: number
          bank_name: string | null
          bank_reference: string | null
          bounced_at: string | null
          bounced_by: string | null
          cheque_id: number
          cheque_number: string
          cleared_at: string | null
          cleared_by: string | null
          collection_id: number
          created_at: string
          created_by: string | null
          dishonor_reason: string | null
          due_date: string | null
          notes: string | null
          status: string
        }
        Insert: {
          amount: number
          bank_name?: string | null
          bank_reference?: string | null
          bounced_at?: string | null
          bounced_by?: string | null
          cheque_id?: number
          cheque_number: string
          cleared_at?: string | null
          cleared_by?: string | null
          collection_id: number
          created_at?: string
          created_by?: string | null
          dishonor_reason?: string | null
          due_date?: string | null
          notes?: string | null
          status?: string
        }
        Update: {
          amount?: number
          bank_name?: string | null
          bank_reference?: string | null
          bounced_at?: string | null
          bounced_by?: string | null
          cheque_id?: number
          cheque_number?: string
          cleared_at?: string | null
          cleared_by?: string | null
          collection_id?: number
          created_at?: string
          created_by?: string | null
          dishonor_reason?: string | null
          due_date?: string | null
          notes?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_cheques_collection_id_fkey"
            columns: ["collection_id"]
            isOneToOne: true
            referencedRelation: "customer_collections"
            referencedColumns: ["collection_id"]
          },
        ]
      }
      customer_collection_allocations: {
        Row: {
          allocation_id: number
          allocation_type: string
          amount: number
          collection_id: number
          created_at: string
          customer_id: number
          reversed_at: string | null
          sales_invoice_id: number | null
        }
        Insert: {
          allocation_id?: number
          allocation_type: string
          amount: number
          collection_id: number
          created_at?: string
          customer_id: number
          reversed_at?: string | null
          sales_invoice_id?: number | null
        }
        Update: {
          allocation_id?: number
          allocation_type?: string
          amount?: number
          collection_id?: number
          created_at?: string
          customer_id?: number
          reversed_at?: string | null
          sales_invoice_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "customer_collection_allocations_collection_id_fkey"
            columns: ["collection_id"]
            isOneToOne: false
            referencedRelation: "customer_collections"
            referencedColumns: ["collection_id"]
          },
          {
            foreignKeyName: "customer_collection_allocations_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["customer_id"]
          },
          {
            foreignKeyName: "customer_collection_allocations_sales_invoice_id_fkey"
            columns: ["sales_invoice_id"]
            isOneToOne: false
            referencedRelation: "sales_invoices"
            referencedColumns: ["sales_invoice_id"]
          },
        ]
      }
      customer_collections: {
        Row: {
          allocation_type: string
          amount: number
          cancellation_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          collection_date: string
          collection_id: number
          collection_number: string
          created_at: string
          created_by: string | null
          custody_settled_at: string | null
          custody_settlement_id: number | null
          custody_settlement_trip_id: number | null
          customer_id: number
          notes: string | null
          payment_method: string
          receipt_destination: string
          reference_number: string | null
          request_id: string | null
          sales_invoice_id: number | null
          sales_rep_id: number | null
          sales_rep_name: string | null
          status: string
          treasury_id: number | null
          trip_id: number | null
          updated_at: string
        }
        Insert: {
          allocation_type?: string
          amount: number
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          collection_date?: string
          collection_id?: number
          collection_number: string
          created_at?: string
          created_by?: string | null
          custody_settled_at?: string | null
          custody_settlement_id?: number | null
          custody_settlement_trip_id?: number | null
          customer_id: number
          notes?: string | null
          payment_method: string
          receipt_destination?: string
          reference_number?: string | null
          request_id?: string | null
          sales_invoice_id?: number | null
          sales_rep_id?: number | null
          sales_rep_name?: string | null
          status?: string
          treasury_id?: number | null
          trip_id?: number | null
          updated_at?: string
        }
        Update: {
          allocation_type?: string
          amount?: number
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          collection_date?: string
          collection_id?: number
          collection_number?: string
          created_at?: string
          created_by?: string | null
          custody_settled_at?: string | null
          custody_settlement_id?: number | null
          custody_settlement_trip_id?: number | null
          customer_id?: number
          notes?: string | null
          payment_method?: string
          receipt_destination?: string
          reference_number?: string | null
          request_id?: string | null
          sales_invoice_id?: number | null
          sales_rep_id?: number | null
          sales_rep_name?: string | null
          status?: string
          treasury_id?: number | null
          trip_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_collections_custody_settlement_id_fkey"
            columns: ["custody_settlement_id"]
            isOneToOne: false
            referencedRelation: "sales_rep_custody_settlements"
            referencedColumns: ["settlement_id"]
          },
          {
            foreignKeyName: "customer_collections_custody_settlement_trip_fkey"
            columns: ["custody_settlement_trip_id"]
            isOneToOne: false
            referencedRelation: "trips"
            referencedColumns: ["trip_id"]
          },
          {
            foreignKeyName: "customer_collections_customer_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["customer_id"]
          },
          {
            foreignKeyName: "customer_collections_invoice_fkey"
            columns: ["sales_invoice_id"]
            isOneToOne: false
            referencedRelation: "sales_invoices"
            referencedColumns: ["sales_invoice_id"]
          },
          {
            foreignKeyName: "customer_collections_sales_rep_fkey"
            columns: ["sales_rep_id"]
            isOneToOne: false
            referencedRelation: "sales_reps"
            referencedColumns: ["sales_rep_id"]
          },
          {
            foreignKeyName: "customer_collections_treasury_id_fkey"
            columns: ["treasury_id"]
            isOneToOne: false
            referencedRelation: "treasuries"
            referencedColumns: ["treasury_id"]
          },
        ]
      }
      customer_credit_balances: {
        Row: {
          balance: number
          customer_id: number
          updated_at: string
        }
        Insert: {
          balance?: number
          customer_id: number
          updated_at?: string
        }
        Update: {
          balance?: number
          customer_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_credit_balances_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: true
            referencedRelation: "customers"
            referencedColumns: ["customer_id"]
          },
        ]
      }
      customer_credit_transactions: {
        Row: {
          amount: number
          balance_after: number
          collection_id: number | null
          created_at: string
          created_by: string | null
          customer_id: number
          direction: string
          notes: string | null
          sales_return_id: number | null
          transaction_id: number
        }
        Insert: {
          amount: number
          balance_after: number
          collection_id?: number | null
          created_at?: string
          created_by?: string | null
          customer_id: number
          direction: string
          notes?: string | null
          sales_return_id?: number | null
          transaction_id?: number
        }
        Update: {
          amount?: number
          balance_after?: number
          collection_id?: number | null
          created_at?: string
          created_by?: string | null
          customer_id?: number
          direction?: string
          notes?: string | null
          sales_return_id?: number | null
          transaction_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "customer_credit_transactions_collection_id_fkey"
            columns: ["collection_id"]
            isOneToOne: false
            referencedRelation: "customer_collections"
            referencedColumns: ["collection_id"]
          },
          {
            foreignKeyName: "customer_credit_transactions_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["customer_id"]
          },
          {
            foreignKeyName: "customer_credit_transactions_sales_return_id_fkey"
            columns: ["sales_return_id"]
            isOneToOne: false
            referencedRelation: "sales_returns"
            referencedColumns: ["sales_return_id"]
          },
        ]
      }
      customer_groups: {
        Row: {
          created_at: string
          created_by: string | null
          customer_group_id: number
          group_code: string
          group_name: string
          is_active: boolean
          notes: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          customer_group_id?: number
          group_code: string
          group_name: string
          is_active?: boolean
          notes?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          customer_group_id?: number
          group_code?: string
          group_name?: string
          is_active?: boolean
          notes?: string | null
        }
        Relationships: []
      }
      customer_price_lists: {
        Row: {
          created_at: string
          created_by: string | null
          customer_group_id: number | null
          customer_id: number | null
          customer_price_list_id: number
          is_active: boolean
          price_list_id: number
          priority: number
          valid_from: string
          valid_to: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          customer_group_id?: number | null
          customer_id?: number | null
          customer_price_list_id?: number
          is_active?: boolean
          price_list_id: number
          priority?: number
          valid_from?: string
          valid_to?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          customer_group_id?: number | null
          customer_id?: number | null
          customer_price_list_id?: number
          is_active?: boolean
          price_list_id?: number
          priority?: number
          valid_from?: string
          valid_to?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "customer_price_lists_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["customer_group_id"]
          },
          {
            foreignKeyName: "customer_price_lists_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["customer_id"]
          },
          {
            foreignKeyName: "customer_price_lists_price_list_id_fkey"
            columns: ["price_list_id"]
            isOneToOne: false
            referencedRelation: "price_lists"
            referencedColumns: ["price_list_id"]
          },
        ]
      }
      customers: {
        Row: {
          address: string | null
          area: string | null
          area_id: number | null
          city: string | null
          city_id: number | null
          created_at: string
          created_by: string | null
          credit_limit: number
          customer_code: string
          customer_group_id: number | null
          customer_id: number
          customer_name: string
          customer_type: string
          governorate_id: number | null
          is_active: boolean
          notes: string | null
          opening_balance: number
          payment_terms_days: number
          phone: string | null
          phone_2: string | null
          sales_rep_id: number | null
          tax_number: string | null
          updated_at: string
          whatsapp: string | null
        }
        Insert: {
          address?: string | null
          area?: string | null
          area_id?: number | null
          city?: string | null
          city_id?: number | null
          created_at?: string
          created_by?: string | null
          credit_limit?: number
          customer_code: string
          customer_group_id?: number | null
          customer_id?: number
          customer_name: string
          customer_type?: string
          governorate_id?: number | null
          is_active?: boolean
          notes?: string | null
          opening_balance?: number
          payment_terms_days?: number
          phone?: string | null
          phone_2?: string | null
          sales_rep_id?: number | null
          tax_number?: string | null
          updated_at?: string
          whatsapp?: string | null
        }
        Update: {
          address?: string | null
          area?: string | null
          area_id?: number | null
          city?: string | null
          city_id?: number | null
          created_at?: string
          created_by?: string | null
          credit_limit?: number
          customer_code?: string
          customer_group_id?: number | null
          customer_id?: number
          customer_name?: string
          customer_type?: string
          governorate_id?: number | null
          is_active?: boolean
          notes?: string | null
          opening_balance?: number
          payment_terms_days?: number
          phone?: string | null
          phone_2?: string | null
          sales_rep_id?: number | null
          tax_number?: string | null
          updated_at?: string
          whatsapp?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "customers_area_fk"
            columns: ["area_id"]
            isOneToOne: false
            referencedRelation: "areas"
            referencedColumns: ["area_id"]
          },
          {
            foreignKeyName: "customers_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["city_id"]
          },
          {
            foreignKeyName: "customers_customer_group_fk"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["customer_group_id"]
          },
          {
            foreignKeyName: "customers_governorate_id_fkey"
            columns: ["governorate_id"]
            isOneToOne: false
            referencedRelation: "governorates"
            referencedColumns: ["governorate_id"]
          },
          {
            foreignKeyName: "customers_sales_rep_id_fkey"
            columns: ["sales_rep_id"]
            isOneToOne: false
            referencedRelation: "sales_reps"
            referencedColumns: ["sales_rep_id"]
          },
        ]
      }
      expense_types: {
        Row: {
          account_id: number | null
          category_group: string
          cost_treatment: string
          created_at: string
          expense_type: string
          expense_type_id: number
          is_active: boolean
        }
        Insert: {
          account_id?: number | null
          category_group: string
          cost_treatment?: string
          created_at?: string
          expense_type: string
          expense_type_id?: number
          is_active?: boolean
        }
        Update: {
          account_id?: number | null
          category_group?: string
          cost_treatment?: string
          created_at?: string
          expense_type?: string
          expense_type_id?: number
          is_active?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "expense_types_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["account_id"]
          },
        ]
      }
      expenses: {
        Row: {
          amount: number
          cancellation_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          cancelled_by_name: string | null
          created_at: string | null
          created_by: string | null
          expense_date: string
          expense_id: number
          expense_type: string
          is_cancelled: boolean
          notes: string | null
          request_id: string | null
          treasury_id: number
          trip_id: number | null
        }
        Insert: {
          amount: number
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cancelled_by_name?: string | null
          created_at?: string | null
          created_by?: string | null
          expense_date?: string
          expense_id?: number
          expense_type: string
          is_cancelled?: boolean
          notes?: string | null
          request_id?: string | null
          treasury_id: number
          trip_id?: number | null
        }
        Update: {
          amount?: number
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cancelled_by_name?: string | null
          created_at?: string | null
          created_by?: string | null
          expense_date?: string
          expense_id?: number
          expense_type?: string
          is_cancelled?: boolean
          notes?: string | null
          request_id?: string | null
          treasury_id?: number
          trip_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "expenses_treasury_id_fkey"
            columns: ["treasury_id"]
            isOneToOne: false
            referencedRelation: "treasuries"
            referencedColumns: ["treasury_id"]
          },
          {
            foreignKeyName: "expenses_trip_id_fkey"
            columns: ["trip_id"]
            isOneToOne: false
            referencedRelation: "trips"
            referencedColumns: ["trip_id"]
          },
        ]
      }
      fixed_asset_depreciation_entries: {
        Row: {
          asset_id: number
          created_at: string
          created_by: string
          depreciation_amount: number
          depreciation_id: number
          depreciation_month: string
          journal_entry_id: number | null
          request_id: string
        }
        Insert: {
          asset_id: number
          created_at?: string
          created_by: string
          depreciation_amount: number
          depreciation_id?: number
          depreciation_month: string
          journal_entry_id?: number | null
          request_id: string
        }
        Update: {
          asset_id?: number
          created_at?: string
          created_by?: string
          depreciation_amount?: number
          depreciation_id?: number
          depreciation_month?: string
          journal_entry_id?: number | null
          request_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fixed_asset_depreciation_entries_asset_id_fkey"
            columns: ["asset_id"]
            isOneToOne: false
            referencedRelation: "fixed_assets"
            referencedColumns: ["asset_id"]
          },
        ]
      }
      fixed_assets: {
        Row: {
          account_id: number
          accumulated_depreciation: number
          acquisition_cost: number
          acquisition_date: string
          asset_category: string
          asset_code: string
          asset_id: number
          asset_name: string
          cancellation_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          created_at: string
          created_by: string
          depreciation_method: string
          disposal_gain_loss: number | null
          disposal_proceeds: number | null
          disposal_reason: string | null
          disposed_at: string | null
          disposed_by: string | null
          location_description: string | null
          notes: string | null
          partner_id: number | null
          partner_transaction_id: number | null
          request_id: string
          residual_value: number
          serial_number: string | null
          source_type: string
          status: string
          supplier_id: number | null
          treasury_id: number | null
          useful_life_months: number | null
        }
        Insert: {
          account_id: number
          accumulated_depreciation?: number
          acquisition_cost: number
          acquisition_date: string
          asset_category: string
          asset_code?: string
          asset_id?: number
          asset_name: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          created_at?: string
          created_by: string
          depreciation_method?: string
          disposal_gain_loss?: number | null
          disposal_proceeds?: number | null
          disposal_reason?: string | null
          disposed_at?: string | null
          disposed_by?: string | null
          location_description?: string | null
          notes?: string | null
          partner_id?: number | null
          partner_transaction_id?: number | null
          request_id: string
          residual_value?: number
          serial_number?: string | null
          source_type?: string
          status?: string
          supplier_id?: number | null
          treasury_id?: number | null
          useful_life_months?: number | null
        }
        Update: {
          account_id?: number
          accumulated_depreciation?: number
          acquisition_cost?: number
          acquisition_date?: string
          asset_category?: string
          asset_code?: string
          asset_id?: number
          asset_name?: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          created_at?: string
          created_by?: string
          depreciation_method?: string
          disposal_gain_loss?: number | null
          disposal_proceeds?: number | null
          disposal_reason?: string | null
          disposed_at?: string | null
          disposed_by?: string | null
          location_description?: string | null
          notes?: string | null
          partner_id?: number | null
          partner_transaction_id?: number | null
          request_id?: string
          residual_value?: number
          serial_number?: string | null
          source_type?: string
          status?: string
          supplier_id?: number | null
          treasury_id?: number | null
          useful_life_months?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "fixed_assets_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["account_id"]
          },
          {
            foreignKeyName: "fixed_assets_partner_id_fkey"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["partner_id"]
          },
          {
            foreignKeyName: "fixed_assets_partner_transaction_id_fkey"
            columns: ["partner_transaction_id"]
            isOneToOne: true
            referencedRelation: "partner_transactions"
            referencedColumns: ["transaction_id"]
          },
          {
            foreignKeyName: "fixed_assets_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["supplier_id"]
          },
          {
            foreignKeyName: "fixed_assets_treasury_id_fkey"
            columns: ["treasury_id"]
            isOneToOne: false
            referencedRelation: "treasuries"
            referencedColumns: ["treasury_id"]
          },
        ]
      }
      governorates: {
        Row: {
          code: string
          created_at: string
          governorate_id: number
          is_active: boolean
          name: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          governorate_id?: number
          is_active?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          governorate_id?: number
          is_active?: boolean
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      inventory_count_lines: {
        Row: {
          counted_loose_quantity: number | null
          counted_quantity: number | null
          counted_units: Json
          counted_value: number | null
          difference_quantity: number | null
          difference_value: number | null
          line_id: number
          location_id: number
          product_id: number
          session_id: number
          system_quantity: number
          system_value: number
          unit_cost: number
        }
        Insert: {
          counted_loose_quantity?: number | null
          counted_quantity?: number | null
          counted_units?: Json
          counted_value?: number | null
          difference_quantity?: number | null
          difference_value?: number | null
          line_id?: number
          location_id: number
          product_id: number
          session_id: number
          system_quantity?: number
          system_value?: number
          unit_cost?: number
        }
        Update: {
          counted_loose_quantity?: number | null
          counted_quantity?: number | null
          counted_units?: Json
          counted_value?: number | null
          difference_quantity?: number | null
          difference_value?: number | null
          line_id?: number
          location_id?: number
          product_id?: number
          session_id?: number
          system_quantity?: number
          system_value?: number
          unit_cost?: number
        }
        Relationships: [
          {
            foreignKeyName: "inventory_count_lines_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "inventory_count_lines_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "inventory_count_lines_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "inventory_count_sessions"
            referencedColumns: ["session_id"]
          },
        ]
      }
      inventory_count_sessions: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          count_date: string
          created_at: string
          created_by: string
          notes: string | null
          session_code: string
          session_id: number
          status: string
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          count_date?: string
          created_at?: string
          created_by: string
          notes?: string | null
          session_code: string
          session_id?: number
          status?: string
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          count_date?: string
          created_at?: string
          created_by?: string
          notes?: string | null
          session_code?: string
          session_id?: number
          status?: string
        }
        Relationships: []
      }
      journal_adjustments: {
        Row: {
          adjustment_id: number
          amount: number
          created_at: string | null
          created_by: string | null
          credit_account: string
          debit_account: string
          description: string
          entry_date: string
          request_id: string | null
        }
        Insert: {
          adjustment_id?: number
          amount?: number
          created_at?: string | null
          created_by?: string | null
          credit_account: string
          debit_account: string
          description: string
          entry_date: string
          request_id?: string | null
        }
        Update: {
          adjustment_id?: number
          amount?: number
          created_at?: string | null
          created_by?: string | null
          credit_account?: string
          debit_account?: string
          description?: string
          entry_date?: string
          request_id?: string | null
        }
        Relationships: []
      }
      journal_entries: {
        Row: {
          account_code: string | null
          created_at: string | null
          credit: number | null
          debit: number | null
          description: string | null
          entry_date: string
          entry_id: number
          entry_number: string | null
          reference_id: number | null
          reference_type: string | null
          reversal_of_entry_id: number | null
          status: string | null
        }
        Insert: {
          account_code?: string | null
          created_at?: string | null
          credit?: number | null
          debit?: number | null
          description?: string | null
          entry_date: string
          entry_id?: number
          entry_number?: string | null
          reference_id?: number | null
          reference_type?: string | null
          reversal_of_entry_id?: number | null
          status?: string | null
        }
        Update: {
          account_code?: string | null
          created_at?: string | null
          credit?: number | null
          debit?: number | null
          description?: string | null
          entry_date?: string
          entry_id?: number
          entry_number?: string | null
          reference_id?: number | null
          reference_type?: string | null
          reversal_of_entry_id?: number | null
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_journal_reversal_original"
            columns: ["reversal_of_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["entry_id"]
          },
        ]
      }
      journal_entry_lines: {
        Row: {
          account_id: number
          credit: number
          debit: number
          description: string | null
          entry_id: number
          line_id: number
        }
        Insert: {
          account_id: number
          credit?: number
          debit?: number
          description?: string | null
          entry_id: number
          line_id?: number
        }
        Update: {
          account_id?: number
          credit?: number
          debit?: number
          description?: string | null
          entry_id?: number
          line_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "fk_journal_lines_entry"
            columns: ["entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["entry_id"]
          },
          {
            foreignKeyName: "journal_entry_lines_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["account_id"]
          },
        ]
      }
      locations: {
        Row: {
          created_at: string
          created_by: string | null
          is_active: boolean
          location_code: string
          location_id: number
          location_name: string
          location_type: string
          notes: string | null
          updated_at: string
          vehicle_asset_id: number | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          is_active?: boolean
          location_code: string
          location_id?: number
          location_name: string
          location_type: string
          notes?: string | null
          updated_at?: string
          vehicle_asset_id?: number | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          is_active?: boolean
          location_code?: string
          location_id?: number
          location_name?: string
          location_type?: string
          notes?: string | null
          updated_at?: string
          vehicle_asset_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "locations_vehicle_asset_id_fkey"
            columns: ["vehicle_asset_id"]
            isOneToOne: false
            referencedRelation: "fixed_assets"
            referencedColumns: ["asset_id"]
          },
        ]
      }
      notification_recipients: {
        Row: {
          created_at: string
          notification_id: string
          notification_recipient_id: string
          read_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          notification_id: string
          notification_recipient_id?: string
          read_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          notification_id?: string
          notification_recipient_id?: string
          read_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_recipients_notification_id_fkey"
            columns: ["notification_id"]
            isOneToOne: false
            referencedRelation: "notifications"
            referencedColumns: ["notification_id"]
          },
          {
            foreignKeyName: "notification_recipients_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["user_id"]
          },
        ]
      }
      notification_rules: {
        Row: {
          created_at: string
          is_active: boolean
          rule_code: string
          rule_config: Json
          rule_id: number
          rule_name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          is_active?: boolean
          rule_code: string
          rule_config?: Json
          rule_id?: number
          rule_name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          is_active?: boolean
          rule_code?: string
          rule_config?: Json
          rule_id?: number
          rule_name?: string
          updated_at?: string
        }
        Relationships: []
      }
      notifications: {
        Row: {
          body: string
          created_at: string
          created_by: string | null
          due_at: string | null
          entity_id: string | null
          entity_type: string | null
          event_key: string
          metadata: Json
          notification_id: string
          notification_type: string
          title: string
        }
        Insert: {
          body: string
          created_at?: string
          created_by?: string | null
          due_at?: string | null
          entity_id?: string | null
          entity_type?: string | null
          event_key: string
          metadata?: Json
          notification_id?: string
          notification_type: string
          title: string
        }
        Update: {
          body?: string
          created_at?: string
          created_by?: string | null
          due_at?: string | null
          entity_id?: string | null
          entity_type?: string | null
          event_key?: string
          metadata?: Json
          notification_id?: string
          notification_type?: string
          title?: string
        }
        Relationships: []
      }
      partner_inventory_contributions: {
        Row: {
          base_quantity: number
          cancellation_reason: string | null
          cancellation_request_id: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          contribution_date: string
          contribution_id: number
          created_at: string
          created_by: string
          entered_quantity: number
          location_id: number
          notes: string | null
          partner_id: number
          partner_transaction_id: number | null
          product_id: number
          request_id: string
          reversal_movement_id: number | null
          status: string
          stock_movement_id: number | null
          total_value: number
          unit_cost: number
          unit_id: number
        }
        Insert: {
          base_quantity: number
          cancellation_reason?: string | null
          cancellation_request_id?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          contribution_date: string
          contribution_id?: number
          created_at?: string
          created_by: string
          entered_quantity: number
          location_id: number
          notes?: string | null
          partner_id: number
          partner_transaction_id?: number | null
          product_id: number
          request_id: string
          reversal_movement_id?: number | null
          status?: string
          stock_movement_id?: number | null
          total_value: number
          unit_cost: number
          unit_id: number
        }
        Update: {
          base_quantity?: number
          cancellation_reason?: string | null
          cancellation_request_id?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          contribution_date?: string
          contribution_id?: number
          created_at?: string
          created_by?: string
          entered_quantity?: number
          location_id?: number
          notes?: string | null
          partner_id?: number
          partner_transaction_id?: number | null
          product_id?: number
          request_id?: string
          reversal_movement_id?: number | null
          status?: string
          stock_movement_id?: number | null
          total_value?: number
          unit_cost?: number
          unit_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "partner_inventory_contributions_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "partner_inventory_contributions_partner_id_fkey"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["partner_id"]
          },
          {
            foreignKeyName: "partner_inventory_contributions_partner_transaction_id_fkey"
            columns: ["partner_transaction_id"]
            isOneToOne: true
            referencedRelation: "partner_transactions"
            referencedColumns: ["transaction_id"]
          },
          {
            foreignKeyName: "partner_inventory_contributions_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "partner_inventory_contributions_reversal_movement_id_fkey"
            columns: ["reversal_movement_id"]
            isOneToOne: true
            referencedRelation: "stock_movements"
            referencedColumns: ["movement_id"]
          },
          {
            foreignKeyName: "partner_inventory_contributions_stock_movement_id_fkey"
            columns: ["stock_movement_id"]
            isOneToOne: true
            referencedRelation: "stock_movements"
            referencedColumns: ["movement_id"]
          },
          {
            foreignKeyName: "partner_inventory_contributions_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
        ]
      }
      partner_profit_distribution_items: {
        Row: {
          amount: number
          created_at: string
          distribution_id: number
          distribution_item_id: number
          partner_id: number
          partner_transaction_id: number | null
          share_percentage: number
        }
        Insert: {
          amount: number
          created_at?: string
          distribution_id: number
          distribution_item_id?: number
          partner_id: number
          partner_transaction_id?: number | null
          share_percentage: number
        }
        Update: {
          amount?: number
          created_at?: string
          distribution_id?: number
          distribution_item_id?: number
          partner_id?: number
          partner_transaction_id?: number | null
          share_percentage?: number
        }
        Relationships: [
          {
            foreignKeyName: "partner_profit_distribution_items_distribution_id_fkey"
            columns: ["distribution_id"]
            isOneToOne: false
            referencedRelation: "partner_profit_distributions"
            referencedColumns: ["distribution_id"]
          },
          {
            foreignKeyName: "partner_profit_distribution_items_partner_id_fkey"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["partner_id"]
          },
          {
            foreignKeyName: "partner_profit_distribution_items_partner_transaction_id_fkey"
            columns: ["partner_transaction_id"]
            isOneToOne: false
            referencedRelation: "partner_transactions"
            referencedColumns: ["transaction_id"]
          },
        ]
      }
      partner_profit_distributions: {
        Row: {
          cancellation_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          created_at: string
          created_by: string
          distribution_id: number
          period_from: string
          period_to: string
          profit_amount: number
          request_id: string
          status: string
        }
        Insert: {
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          created_at?: string
          created_by: string
          distribution_id?: number
          period_from: string
          period_to: string
          profit_amount: number
          request_id: string
          status?: string
        }
        Update: {
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          created_at?: string
          created_by?: string
          distribution_id?: number
          period_from?: string
          period_to?: string
          profit_amount?: number
          request_id?: string
          status?: string
        }
        Relationships: []
      }
      partner_transactions: {
        Row: {
          amount: number
          created_at: string | null
          created_by: string | null
          notes: string | null
          partner_id: number
          profit_distribution_item_id: number | null
          request_id: string | null
          reverses_transaction_id: number | null
          transaction_date: string
          transaction_id: number
          transaction_type: string
          treasury_id: number | null
        }
        Insert: {
          amount: number
          created_at?: string | null
          created_by?: string | null
          notes?: string | null
          partner_id: number
          profit_distribution_item_id?: number | null
          request_id?: string | null
          reverses_transaction_id?: number | null
          transaction_date?: string
          transaction_id?: number
          transaction_type: string
          treasury_id?: number | null
        }
        Update: {
          amount?: number
          created_at?: string | null
          created_by?: string | null
          notes?: string | null
          partner_id?: number
          profit_distribution_item_id?: number | null
          request_id?: string | null
          reverses_transaction_id?: number | null
          transaction_date?: string
          transaction_id?: number
          transaction_type?: string
          treasury_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "partner_transactions_partner_id_fkey"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["partner_id"]
          },
          {
            foreignKeyName: "partner_transactions_profit_distribution_item_id_fkey"
            columns: ["profit_distribution_item_id"]
            isOneToOne: false
            referencedRelation: "partner_profit_distribution_items"
            referencedColumns: ["distribution_item_id"]
          },
          {
            foreignKeyName: "partner_transactions_reverses_transaction_id_fkey"
            columns: ["reverses_transaction_id"]
            isOneToOne: false
            referencedRelation: "partner_transactions"
            referencedColumns: ["transaction_id"]
          },
          {
            foreignKeyName: "partner_transactions_treasury_id_fkey"
            columns: ["treasury_id"]
            isOneToOne: false
            referencedRelation: "treasuries"
            referencedColumns: ["treasury_id"]
          },
        ]
      }
      partners: {
        Row: {
          created_at: string | null
          current_balance: number | null
          is_active: boolean
          notes: string | null
          opening_balance: number
          partner_id: number
          partner_name: string
          phone: string | null
          share_percentage: number | null
        }
        Insert: {
          created_at?: string | null
          current_balance?: number | null
          is_active?: boolean
          notes?: string | null
          opening_balance?: number
          partner_id?: number
          partner_name: string
          phone?: string | null
          share_percentage?: number | null
        }
        Update: {
          created_at?: string | null
          current_balance?: number | null
          is_active?: boolean
          notes?: string | null
          opening_balance?: number
          partner_id?: number
          partner_name?: string
          phone?: string | null
          share_percentage?: number | null
        }
        Relationships: []
      }
      price_list_items: {
        Row: {
          created_at: string
          is_active: boolean
          maximum_price: number | null
          minimum_price: number | null
          price_list_id: number
          price_list_item_id: number
          product_id: number
          selling_price: number
          unit_id: number
        }
        Insert: {
          created_at?: string
          is_active?: boolean
          maximum_price?: number | null
          minimum_price?: number | null
          price_list_id: number
          price_list_item_id?: number
          product_id: number
          selling_price: number
          unit_id: number
        }
        Update: {
          created_at?: string
          is_active?: boolean
          maximum_price?: number | null
          minimum_price?: number | null
          price_list_id?: number
          price_list_item_id?: number
          product_id?: number
          selling_price?: number
          unit_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "price_list_items_price_list_id_fkey"
            columns: ["price_list_id"]
            isOneToOne: false
            referencedRelation: "price_lists"
            referencedColumns: ["price_list_id"]
          },
          {
            foreignKeyName: "price_list_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "price_list_items_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
        ]
      }
      price_lists: {
        Row: {
          approval_status: string
          approved_at: string | null
          approved_by: string | null
          created_at: string
          created_by: string | null
          is_active: boolean
          is_default: boolean
          notes: string | null
          price_list_code: string
          price_list_id: number
          price_list_name: string
          valid_from: string
          valid_to: string | null
        }
        Insert: {
          approval_status?: string
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          created_by?: string | null
          is_active?: boolean
          is_default?: boolean
          notes?: string | null
          price_list_code: string
          price_list_id?: number
          price_list_name: string
          valid_from?: string
          valid_to?: string | null
        }
        Update: {
          approval_status?: string
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          created_by?: string | null
          is_active?: boolean
          is_default?: boolean
          notes?: string | null
          price_list_code?: string
          price_list_id?: number
          price_list_name?: string
          valid_from?: string
          valid_to?: string | null
        }
        Relationships: []
      }
      product_categories: {
        Row: {
          category_code: string
          category_id: number
          category_name: string
          category_type: string
          created_at: string
          created_by: string | null
          description: string | null
          is_active: boolean
          parent_category_id: number | null
        }
        Insert: {
          category_code: string
          category_id?: number
          category_name: string
          category_type: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          is_active?: boolean
          parent_category_id?: number | null
        }
        Update: {
          category_code?: string
          category_id?: number
          category_name?: string
          category_type?: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          is_active?: boolean
          parent_category_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "product_categories_parent_category_id_fkey"
            columns: ["parent_category_id"]
            isOneToOne: false
            referencedRelation: "product_categories"
            referencedColumns: ["category_id"]
          },
        ]
      }
      product_packaging_options: {
        Row: {
          created_at: string
          created_by: string | null
          is_active: boolean
          option_name: string
          package_option_id: number
          product_id: number
          sort_order: number
          unit_id: number
          updated_at: string
          weight_kg: number
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          is_active?: boolean
          option_name: string
          package_option_id?: number
          product_id: number
          sort_order?: number
          unit_id: number
          updated_at?: string
          weight_kg: number
        }
        Update: {
          created_at?: string
          created_by?: string | null
          is_active?: boolean
          option_name?: string
          package_option_id?: number
          product_id?: number
          sort_order?: number
          unit_id?: number
          updated_at?: string
          weight_kg?: number
        }
        Relationships: [
          {
            foreignKeyName: "product_packaging_options_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "product_packaging_options_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
        ]
      }
      product_unit_conversions: {
        Row: {
          base_quantity_per_unit: number
          conversion_id: number
          created_at: string
          is_active: boolean
          product_id: number
          unit_id: number
          updated_at: string
        }
        Insert: {
          base_quantity_per_unit: number
          conversion_id?: number
          created_at?: string
          is_active?: boolean
          product_id: number
          unit_id: number
          updated_at?: string
        }
        Update: {
          base_quantity_per_unit?: number
          conversion_id?: number
          created_at?: string
          is_active?: boolean
          product_id?: number
          unit_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_unit_conversions_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "product_unit_conversions_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
        ]
      }
      production_order_expense_allocations: {
        Row: {
          account_id: number
          allocated_amount: number
          allocation_id: number
          created_at: string
          created_by: string
          expense_id: number
          expense_type: string
          journal_entry_id: number | null
          order_id: number
          reversed_at: string | null
          status: string
        }
        Insert: {
          account_id: number
          allocated_amount: number
          allocation_id?: number
          created_at?: string
          created_by: string
          expense_id: number
          expense_type: string
          journal_entry_id?: number | null
          order_id: number
          reversed_at?: string | null
          status?: string
        }
        Update: {
          account_id?: number
          allocated_amount?: number
          allocation_id?: number
          created_at?: string
          created_by?: string
          expense_id?: number
          expense_type?: string
          journal_entry_id?: number | null
          order_id?: number
          reversed_at?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "production_order_expense_allocations_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["account_id"]
          },
          {
            foreignKeyName: "production_order_expense_allocations_expense_id_fkey"
            columns: ["expense_id"]
            isOneToOne: false
            referencedRelation: "expenses"
            referencedColumns: ["expense_id"]
          },
          {
            foreignKeyName: "production_order_expense_allocations_journal_entry_id_fkey"
            columns: ["journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["entry_id"]
          },
          {
            foreignKeyName: "production_order_expense_allocations_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "production_orders"
            referencedColumns: ["order_id"]
          },
        ]
      }
      production_order_materials: {
        Row: {
          actual_base_quantity: number | null
          actual_cost: number | null
          actual_quantity: number | null
          is_extra: boolean
          material_id: number
          order_id: number
          raw_product_id: number
          request_id: string | null
          required_quantity: number
          unit_id: number
        }
        Insert: {
          actual_base_quantity?: number | null
          actual_cost?: number | null
          actual_quantity?: number | null
          is_extra?: boolean
          material_id?: number
          order_id: number
          raw_product_id: number
          request_id?: string | null
          required_quantity: number
          unit_id: number
        }
        Update: {
          actual_base_quantity?: number | null
          actual_cost?: number | null
          actual_quantity?: number | null
          is_extra?: boolean
          material_id?: number
          order_id?: number
          raw_product_id?: number
          request_id?: string | null
          required_quantity?: number
          unit_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "production_order_materials_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "production_orders"
            referencedColumns: ["order_id"]
          },
          {
            foreignKeyName: "production_order_materials_raw_product_id_fkey"
            columns: ["raw_product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "production_order_materials_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
        ]
      }
      production_orders: {
        Row: {
          actual_output_quantity: number | null
          completed_at: string | null
          cost_allocation_details: Json | null
          created_at: string
          created_by: string | null
          factory_location_id: number
          notes: string | null
          order_id: number
          order_number: string
          output_lot_id: number | null
          output_product_id: number
          output_unit_cost: number | null
          output_unit_id: number
          recipe_id: number
          recipe_version_number: number
          request_id: string | null
          status: string
          target_quantity: number
          total_direct_cost: number
          total_material_cost: number | null
          total_production_cost: number
          updated_at: string
        }
        Insert: {
          actual_output_quantity?: number | null
          completed_at?: string | null
          cost_allocation_details?: Json | null
          created_at?: string
          created_by?: string | null
          factory_location_id: number
          notes?: string | null
          order_id?: number
          order_number: string
          output_lot_id?: number | null
          output_product_id: number
          output_unit_cost?: number | null
          output_unit_id: number
          recipe_id: number
          recipe_version_number: number
          request_id?: string | null
          status?: string
          target_quantity: number
          total_direct_cost?: number
          total_material_cost?: number | null
          total_production_cost?: number
          updated_at?: string
        }
        Update: {
          actual_output_quantity?: number | null
          completed_at?: string | null
          cost_allocation_details?: Json | null
          created_at?: string
          created_by?: string | null
          factory_location_id?: number
          notes?: string | null
          order_id?: number
          order_number?: string
          output_lot_id?: number | null
          output_product_id?: number
          output_unit_cost?: number | null
          output_unit_id?: number
          recipe_id?: number
          recipe_version_number?: number
          request_id?: string | null
          status?: string
          target_quantity?: number
          total_direct_cost?: number
          total_material_cost?: number | null
          total_production_cost?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "production_orders_factory_location_id_fkey"
            columns: ["factory_location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "production_orders_output_lot_id_fkey"
            columns: ["output_lot_id"]
            isOneToOne: false
            referencedRelation: "stock_lots"
            referencedColumns: ["lot_id"]
          },
          {
            foreignKeyName: "production_orders_output_product_id_fkey"
            columns: ["output_product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "production_orders_output_unit_id_fkey"
            columns: ["output_unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
          {
            foreignKeyName: "production_orders_recipe_id_fkey"
            columns: ["recipe_id"]
            isOneToOne: false
            referencedRelation: "recipes"
            referencedColumns: ["recipe_id"]
          },
        ]
      }
      production_rework_consumptions: {
        Row: {
          consumption_id: number
          created_at: string
          location_id: number
          movement_id: number
          product_id: number
          production_order_id: number
          quantity: number
          reservation_id: number | null
          return_item_id: number
          reversed_quantity: number
        }
        Insert: {
          consumption_id?: number
          created_at?: string
          location_id: number
          movement_id: number
          product_id: number
          production_order_id: number
          quantity: number
          reservation_id?: number | null
          return_item_id: number
          reversed_quantity?: number
        }
        Update: {
          consumption_id?: number
          created_at?: string
          location_id?: number
          movement_id?: number
          product_id?: number
          production_order_id?: number
          quantity?: number
          reservation_id?: number | null
          return_item_id?: number
          reversed_quantity?: number
        }
        Relationships: [
          {
            foreignKeyName: "production_rework_consumptions_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "production_rework_consumptions_movement_id_fkey"
            columns: ["movement_id"]
            isOneToOne: false
            referencedRelation: "stock_movements"
            referencedColumns: ["movement_id"]
          },
          {
            foreignKeyName: "production_rework_consumptions_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "production_rework_consumptions_production_order_id_fkey"
            columns: ["production_order_id"]
            isOneToOne: false
            referencedRelation: "production_orders"
            referencedColumns: ["order_id"]
          },
          {
            foreignKeyName: "production_rework_consumptions_reservation_id_fkey"
            columns: ["reservation_id"]
            isOneToOne: false
            referencedRelation: "reservations"
            referencedColumns: ["reservation_id"]
          },
          {
            foreignKeyName: "production_rework_consumptions_return_item_id_fkey"
            columns: ["return_item_id"]
            isOneToOne: false
            referencedRelation: "sales_return_items"
            referencedColumns: ["return_item_id"]
          },
        ]
      }
      products: {
        Row: {
          barcode: string | null
          base_unit_id: number
          can_be_loaded: boolean
          can_be_produced: boolean
          can_be_purchased: boolean
          can_be_recipe_ingredient: boolean
          can_be_reserved: boolean
          can_be_sold: boolean
          carton_weight_kg: number | null
          category_id: number
          created_at: string
          created_by: string | null
          has_recipe: boolean
          is_active: boolean
          max_selling_price: number | null
          maximum_stock: number | null
          min_selling_price: number | null
          minimum_stock: number
          notes: string | null
          product_code: string
          product_id: number
          product_name: string
          product_type: string
          purchase_unit_id: number | null
          requires_refrigeration: boolean
          sales_unit_id: number | null
          shelf_life_days: number | null
          shelf_life_months: number | null
          target_selling_price: number | null
          target_stock: number
          unit_weight_kg: number | null
          units_per_carton: number | null
          updated_at: string
        }
        Insert: {
          barcode?: string | null
          base_unit_id: number
          can_be_loaded?: boolean
          can_be_produced?: boolean
          can_be_purchased?: boolean
          can_be_recipe_ingredient?: boolean
          can_be_reserved?: boolean
          can_be_sold?: boolean
          carton_weight_kg?: number | null
          category_id: number
          created_at?: string
          created_by?: string | null
          has_recipe?: boolean
          is_active?: boolean
          max_selling_price?: number | null
          maximum_stock?: number | null
          min_selling_price?: number | null
          minimum_stock?: number
          notes?: string | null
          product_code: string
          product_id?: number
          product_name: string
          product_type: string
          purchase_unit_id?: number | null
          requires_refrigeration?: boolean
          sales_unit_id?: number | null
          shelf_life_days?: number | null
          shelf_life_months?: number | null
          target_selling_price?: number | null
          target_stock?: number
          unit_weight_kg?: number | null
          units_per_carton?: number | null
          updated_at?: string
        }
        Update: {
          barcode?: string | null
          base_unit_id?: number
          can_be_loaded?: boolean
          can_be_produced?: boolean
          can_be_purchased?: boolean
          can_be_recipe_ingredient?: boolean
          can_be_reserved?: boolean
          can_be_sold?: boolean
          carton_weight_kg?: number | null
          category_id?: number
          created_at?: string
          created_by?: string | null
          has_recipe?: boolean
          is_active?: boolean
          max_selling_price?: number | null
          maximum_stock?: number | null
          min_selling_price?: number | null
          minimum_stock?: number
          notes?: string | null
          product_code?: string
          product_id?: number
          product_name?: string
          product_type?: string
          purchase_unit_id?: number | null
          requires_refrigeration?: boolean
          sales_unit_id?: number | null
          shelf_life_days?: number | null
          shelf_life_months?: number | null
          target_selling_price?: number | null
          target_stock?: number
          unit_weight_kg?: number | null
          units_per_carton?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "products_base_unit_id_fkey"
            columns: ["base_unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
          {
            foreignKeyName: "products_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "product_categories"
            referencedColumns: ["category_id"]
          },
          {
            foreignKeyName: "products_purchase_unit_id_fkey"
            columns: ["purchase_unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
          {
            foreignKeyName: "products_sales_unit_id_fkey"
            columns: ["sales_unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
        ]
      }
      purchase_invoice_items: {
        Row: {
          base_quantity: number
          conversion_factor: number | null
          created_at: string
          expires_on: string | null
          item_id: number
          line_total: number
          manufactured_on: string | null
          package_weight_kg: number | null
          product_id: number
          purchase_invoice_id: number
          quantity: number
          supplier_lot_code: string | null
          unit_id: number
          unit_price: number
        }
        Insert: {
          base_quantity: number
          conversion_factor?: number | null
          created_at?: string
          expires_on?: string | null
          item_id?: number
          line_total: number
          manufactured_on?: string | null
          package_weight_kg?: number | null
          product_id: number
          purchase_invoice_id: number
          quantity: number
          supplier_lot_code?: string | null
          unit_id: number
          unit_price: number
        }
        Update: {
          base_quantity?: number
          conversion_factor?: number | null
          created_at?: string
          expires_on?: string | null
          item_id?: number
          line_total?: number
          manufactured_on?: string | null
          package_weight_kg?: number | null
          product_id?: number
          purchase_invoice_id?: number
          quantity?: number
          supplier_lot_code?: string | null
          unit_id?: number
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "purchase_invoice_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "purchase_invoice_items_purchase_invoice_id_fkey"
            columns: ["purchase_invoice_id"]
            isOneToOne: false
            referencedRelation: "purchase_invoices"
            referencedColumns: ["purchase_invoice_id"]
          },
          {
            foreignKeyName: "purchase_invoice_items_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
        ]
      }
      purchase_invoices: {
        Row: {
          cancellation_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          created_at: string
          created_by: string | null
          discount: number
          invoice_date: string
          invoice_number: string
          location_id: number
          net_total: number
          notes: string | null
          purchase_invoice_id: number
          request_id: string | null
          status: string
          subtotal: number
          supplier_id: number
          treasury_id: number | null
          updated_at: string
        }
        Insert: {
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          created_at?: string
          created_by?: string | null
          discount?: number
          invoice_date?: string
          invoice_number: string
          location_id: number
          net_total?: number
          notes?: string | null
          purchase_invoice_id?: number
          request_id?: string | null
          status?: string
          subtotal?: number
          supplier_id: number
          treasury_id?: number | null
          updated_at?: string
        }
        Update: {
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          created_at?: string
          created_by?: string | null
          discount?: number
          invoice_date?: string
          invoice_number?: string
          location_id?: number
          net_total?: number
          notes?: string | null
          purchase_invoice_id?: number
          request_id?: string | null
          status?: string
          subtotal?: number
          supplier_id?: number
          treasury_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "purchase_invoices_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "purchase_invoices_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["supplier_id"]
          },
          {
            foreignKeyName: "purchase_invoices_treasury_id_fkey"
            columns: ["treasury_id"]
            isOneToOne: false
            referencedRelation: "treasuries"
            referencedColumns: ["treasury_id"]
          },
        ]
      }
      purchase_landed_cost_allocations: {
        Row: {
          allocated_amount: number
          allocated_cost_per_base_unit: number
          allocation_id: number
          invoice_base_quantity: number
          landed_cost_id: number
          product_id: number
        }
        Insert: {
          allocated_amount: number
          allocated_cost_per_base_unit: number
          allocation_id?: number
          invoice_base_quantity: number
          landed_cost_id: number
          product_id: number
        }
        Update: {
          allocated_amount?: number
          allocated_cost_per_base_unit?: number
          allocation_id?: number
          invoice_base_quantity?: number
          landed_cost_id?: number
          product_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "purchase_landed_cost_allocations_landed_cost_id_fkey"
            columns: ["landed_cost_id"]
            isOneToOne: false
            referencedRelation: "purchase_landed_costs"
            referencedColumns: ["landed_cost_id"]
          },
          {
            foreignKeyName: "purchase_landed_cost_allocations_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
        ]
      }
      purchase_landed_costs: {
        Row: {
          amount: number
          cancellation_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          cost_date: string
          created_at: string
          created_by: string
          expense_id: number | null
          landed_cost_id: number
          notes: string | null
          purchase_invoice_id: number
          request_id: string
          source_type: string
          status: string
          supplier_id: number | null
          treasury_id: number | null
        }
        Insert: {
          amount: number
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cost_date?: string
          created_at?: string
          created_by: string
          expense_id?: number | null
          landed_cost_id?: number
          notes?: string | null
          purchase_invoice_id: number
          request_id: string
          source_type: string
          status?: string
          supplier_id?: number | null
          treasury_id?: number | null
        }
        Update: {
          amount?: number
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cost_date?: string
          created_at?: string
          created_by?: string
          expense_id?: number | null
          landed_cost_id?: number
          notes?: string | null
          purchase_invoice_id?: number
          request_id?: string
          source_type?: string
          status?: string
          supplier_id?: number | null
          treasury_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "purchase_landed_costs_expense_id_fkey"
            columns: ["expense_id"]
            isOneToOne: false
            referencedRelation: "expenses"
            referencedColumns: ["expense_id"]
          },
          {
            foreignKeyName: "purchase_landed_costs_purchase_invoice_id_fkey"
            columns: ["purchase_invoice_id"]
            isOneToOne: false
            referencedRelation: "purchase_invoices"
            referencedColumns: ["purchase_invoice_id"]
          },
          {
            foreignKeyName: "purchase_landed_costs_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["supplier_id"]
          },
          {
            foreignKeyName: "purchase_landed_costs_treasury_id_fkey"
            columns: ["treasury_id"]
            isOneToOne: false
            referencedRelation: "treasuries"
            referencedColumns: ["treasury_id"]
          },
        ]
      }
      purchase_return_items: {
        Row: {
          base_quantity: number | null
          conversion_factor: number | null
          item_id: number
          line_total: number
          product_id: number | null
          purchase_invoice_item_id: number | null
          quantity: number
          return_id: number | null
          unit_id: number | null
          unit_price: number
        }
        Insert: {
          base_quantity?: number | null
          conversion_factor?: number | null
          item_id?: number
          line_total: number
          product_id?: number | null
          purchase_invoice_item_id?: number | null
          quantity: number
          return_id?: number | null
          unit_id?: number | null
          unit_price: number
        }
        Update: {
          base_quantity?: number | null
          conversion_factor?: number | null
          item_id?: number
          line_total?: number
          product_id?: number | null
          purchase_invoice_item_id?: number | null
          quantity?: number
          return_id?: number | null
          unit_id?: number | null
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "purchase_return_items_invoice_item_fkey"
            columns: ["purchase_invoice_item_id"]
            isOneToOne: false
            referencedRelation: "purchase_invoice_items"
            referencedColumns: ["item_id"]
          },
          {
            foreignKeyName: "purchase_return_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "purchase_return_items_return_id_fkey"
            columns: ["return_id"]
            isOneToOne: false
            referencedRelation: "purchase_returns"
            referencedColumns: ["return_id"]
          },
          {
            foreignKeyName: "purchase_return_items_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
        ]
      }
      purchase_returns: {
        Row: {
          cancellation_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          created_at: string | null
          created_by: string | null
          is_cancelled: boolean
          notes: string | null
          purchase_invoice_id: number | null
          request_id: string | null
          request_payload: Json | null
          return_date: string
          return_id: number
          return_number: string
          settlement_method: string
          supplier_id: number | null
          total_return_amount: number
          treasury_id: number | null
        }
        Insert: {
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          created_at?: string | null
          created_by?: string | null
          is_cancelled?: boolean
          notes?: string | null
          purchase_invoice_id?: number | null
          request_id?: string | null
          request_payload?: Json | null
          return_date: string
          return_id?: number
          return_number: string
          settlement_method?: string
          supplier_id?: number | null
          total_return_amount: number
          treasury_id?: number | null
        }
        Update: {
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          created_at?: string | null
          created_by?: string | null
          is_cancelled?: boolean
          notes?: string | null
          purchase_invoice_id?: number | null
          request_id?: string | null
          request_payload?: Json | null
          return_date?: string
          return_id?: number
          return_number?: string
          settlement_method?: string
          supplier_id?: number | null
          total_return_amount?: number
          treasury_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "purchase_returns_purchase_invoice_id_fkey"
            columns: ["purchase_invoice_id"]
            isOneToOne: false
            referencedRelation: "purchase_invoices"
            referencedColumns: ["purchase_invoice_id"]
          },
          {
            foreignKeyName: "purchase_returns_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["supplier_id"]
          },
          {
            foreignKeyName: "purchase_returns_treasury_id_fkey"
            columns: ["treasury_id"]
            isOneToOne: false
            referencedRelation: "treasuries"
            referencedColumns: ["treasury_id"]
          },
        ]
      }
      recipe_items: {
        Row: {
          created_at: string | null
          ingredient_product_id: number | null
          notes: string | null
          quantity: number | null
          raw_product_id: number | null
          recipe_id: number
          recipe_item_id: number
          sequence_no: number | null
          unit_id: number | null
          waste_percentage: number | null
        }
        Insert: {
          created_at?: string | null
          ingredient_product_id?: number | null
          notes?: string | null
          quantity?: number | null
          raw_product_id?: number | null
          recipe_id: number
          recipe_item_id?: number
          sequence_no?: number | null
          unit_id?: number | null
          waste_percentage?: number | null
        }
        Update: {
          created_at?: string | null
          ingredient_product_id?: number | null
          notes?: string | null
          quantity?: number | null
          raw_product_id?: number | null
          recipe_id?: number
          recipe_item_id?: number
          sequence_no?: number | null
          unit_id?: number | null
          waste_percentage?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "recipe_items_product_fkey"
            columns: ["ingredient_product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "recipe_items_raw_product_id_fkey"
            columns: ["raw_product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "recipe_items_recipe_fkey"
            columns: ["recipe_id"]
            isOneToOne: false
            referencedRelation: "recipes"
            referencedColumns: ["recipe_id"]
          },
          {
            foreignKeyName: "recipe_items_unit_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
        ]
      }
      recipe_movements: {
        Row: {
          created_at: string | null
          created_by: string | null
          movement_id: number
          movement_type: string | null
          notes: string | null
          quantity: number | null
          recipe_id: number | null
        }
        Insert: {
          created_at?: string | null
          created_by?: string | null
          movement_id?: number
          movement_type?: string | null
          notes?: string | null
          quantity?: number | null
          recipe_id?: number | null
        }
        Update: {
          created_at?: string | null
          created_by?: string | null
          movement_id?: number
          movement_type?: string | null
          notes?: string | null
          quantity?: number | null
          recipe_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "recipe_movements_recipe_id_fkey"
            columns: ["recipe_id"]
            isOneToOne: false
            referencedRelation: "recipes"
            referencedColumns: ["recipe_id"]
          },
        ]
      }
      recipes: {
        Row: {
          created_at: string | null
          created_by: string | null
          is_active: boolean | null
          notes: string | null
          output_quantity: number | null
          preparation_notes: string | null
          product_id: number | null
          recipe_code: string | null
          recipe_id: number
          recipe_name: string | null
          unit_id: number | null
          updated_at: string | null
          version_number: number | null
          yield_quantity: number | null
          yield_unit_id: number | null
        }
        Insert: {
          created_at?: string | null
          created_by?: string | null
          is_active?: boolean | null
          notes?: string | null
          output_quantity?: number | null
          preparation_notes?: string | null
          product_id?: number | null
          recipe_code?: string | null
          recipe_id?: number
          recipe_name?: string | null
          unit_id?: number | null
          updated_at?: string | null
          version_number?: number | null
          yield_quantity?: number | null
          yield_unit_id?: number | null
        }
        Update: {
          created_at?: string | null
          created_by?: string | null
          is_active?: boolean | null
          notes?: string | null
          output_quantity?: number | null
          preparation_notes?: string | null
          product_id?: number | null
          recipe_code?: string | null
          recipe_id?: number
          recipe_name?: string | null
          unit_id?: number | null
          updated_at?: string | null
          version_number?: number | null
          yield_quantity?: number | null
          yield_unit_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "recipes_product_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "recipes_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
          {
            foreignKeyName: "recipes_yield_unit_fkey"
            columns: ["yield_unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
        ]
      }
      reservations: {
        Row: {
          created_at: string | null
          created_by: string | null
          customer_id: number | null
          location_id: number | null
          notes: string | null
          product_id: number | null
          quantity: number
          request_id: string | null
          reservation_id: number
          reserved_until: string | null
          source_return_item_id: number | null
          status: string | null
        }
        Insert: {
          created_at?: string | null
          created_by?: string | null
          customer_id?: number | null
          location_id?: number | null
          notes?: string | null
          product_id?: number | null
          quantity?: number
          request_id?: string | null
          reservation_id?: number
          reserved_until?: string | null
          source_return_item_id?: number | null
          status?: string | null
        }
        Update: {
          created_at?: string | null
          created_by?: string | null
          customer_id?: number | null
          location_id?: number | null
          notes?: string | null
          product_id?: number | null
          quantity?: number
          request_id?: string | null
          reservation_id?: number
          reserved_until?: string | null
          source_return_item_id?: number | null
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "reservations_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["customer_id"]
          },
          {
            foreignKeyName: "reservations_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "reservations_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "reservations_source_return_item_fk"
            columns: ["source_return_item_id"]
            isOneToOne: false
            referencedRelation: "sales_return_items"
            referencedColumns: ["return_item_id"]
          },
        ]
      }
      sales_invoice_items: {
        Row: {
          base_quantity: number | null
          conversion_factor: number | null
          created_at: string
          discount_amount: number
          discount_percent: number
          line_total: number
          lot_id: number | null
          notes: string | null
          package_option_id: number | null
          package_weight_kg: number | null
          product_id: number
          quantity: number
          sales_invoice_id: number
          sales_invoice_item_id: number
          sequence_no: number
          unit_id: number
          unit_price: number
        }
        Insert: {
          base_quantity?: number | null
          conversion_factor?: number | null
          created_at?: string
          discount_amount?: number
          discount_percent?: number
          line_total?: number
          lot_id?: number | null
          notes?: string | null
          package_option_id?: number | null
          package_weight_kg?: number | null
          product_id: number
          quantity: number
          sales_invoice_id: number
          sales_invoice_item_id?: number
          sequence_no?: number
          unit_id: number
          unit_price: number
        }
        Update: {
          base_quantity?: number | null
          conversion_factor?: number | null
          created_at?: string
          discount_amount?: number
          discount_percent?: number
          line_total?: number
          lot_id?: number | null
          notes?: string | null
          package_option_id?: number | null
          package_weight_kg?: number | null
          product_id?: number
          quantity?: number
          sales_invoice_id?: number
          sales_invoice_item_id?: number
          sequence_no?: number
          unit_id?: number
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "sales_invoice_items_invoice_fkey"
            columns: ["sales_invoice_id"]
            isOneToOne: false
            referencedRelation: "sales_invoices"
            referencedColumns: ["sales_invoice_id"]
          },
          {
            foreignKeyName: "sales_invoice_items_lot_fk"
            columns: ["lot_id"]
            isOneToOne: false
            referencedRelation: "stock_lots"
            referencedColumns: ["lot_id"]
          },
          {
            foreignKeyName: "sales_invoice_items_package_option_id_fkey"
            columns: ["package_option_id"]
            isOneToOne: false
            referencedRelation: "product_packaging_options"
            referencedColumns: ["package_option_id"]
          },
          {
            foreignKeyName: "sales_invoice_items_product_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "sales_invoice_items_unit_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
        ]
      }
      sales_invoices: {
        Row: {
          created_at: string
          created_by: string | null
          customer_id: number
          discount_amount: number
          due_date: string | null
          e_invoice_status: string | null
          invoice_date: string
          invoice_number: string
          location_id: number | null
          net_total: number
          notes: string | null
          paid_amount: number
          payment_method: string
          payment_terms_days: number
          price_list_id: number | null
          remaining_amount: number
          request_id: string | null
          sales_invoice_id: number
          sales_order_id: number | null
          sales_rep_id: number | null
          status: string
          subtotal: number
          tax_document_id: string | null
          treasury_id: number | null
          trip_id: number | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          customer_id: number
          discount_amount?: number
          due_date?: string | null
          e_invoice_status?: string | null
          invoice_date?: string
          invoice_number: string
          location_id?: number | null
          net_total?: number
          notes?: string | null
          paid_amount?: number
          payment_method?: string
          payment_terms_days?: number
          price_list_id?: number | null
          remaining_amount?: number
          request_id?: string | null
          sales_invoice_id?: number
          sales_order_id?: number | null
          sales_rep_id?: number | null
          status?: string
          subtotal?: number
          tax_document_id?: string | null
          treasury_id?: number | null
          trip_id?: number | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          customer_id?: number
          discount_amount?: number
          due_date?: string | null
          e_invoice_status?: string | null
          invoice_date?: string
          invoice_number?: string
          location_id?: number | null
          net_total?: number
          notes?: string | null
          paid_amount?: number
          payment_method?: string
          payment_terms_days?: number
          price_list_id?: number | null
          remaining_amount?: number
          request_id?: string | null
          sales_invoice_id?: number
          sales_order_id?: number | null
          sales_rep_id?: number | null
          status?: string
          subtotal?: number
          tax_document_id?: string | null
          treasury_id?: number | null
          trip_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "sales_invoices_customer_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["customer_id"]
          },
          {
            foreignKeyName: "sales_invoices_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "sales_invoices_price_list_fk"
            columns: ["price_list_id"]
            isOneToOne: false
            referencedRelation: "price_lists"
            referencedColumns: ["price_list_id"]
          },
          {
            foreignKeyName: "sales_invoices_sales_rep_fkey"
            columns: ["sales_rep_id"]
            isOneToOne: false
            referencedRelation: "sales_reps"
            referencedColumns: ["sales_rep_id"]
          },
          {
            foreignKeyName: "sales_invoices_treasury_id_fkey"
            columns: ["treasury_id"]
            isOneToOne: false
            referencedRelation: "treasuries"
            referencedColumns: ["treasury_id"]
          },
        ]
      }
      sales_rep_areas: {
        Row: {
          area_id: number
          created_at: string
          created_by: string | null
          is_active: boolean
          notes: string | null
          sales_rep_area_id: number
          sales_rep_id: number
        }
        Insert: {
          area_id: number
          created_at?: string
          created_by?: string | null
          is_active?: boolean
          notes?: string | null
          sales_rep_area_id?: number
          sales_rep_id: number
        }
        Update: {
          area_id?: number
          created_at?: string
          created_by?: string | null
          is_active?: boolean
          notes?: string | null
          sales_rep_area_id?: number
          sales_rep_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "sales_rep_areas_area_id_fkey"
            columns: ["area_id"]
            isOneToOne: false
            referencedRelation: "areas"
            referencedColumns: ["area_id"]
          },
          {
            foreignKeyName: "sales_rep_areas_sales_rep_id_fkey"
            columns: ["sales_rep_id"]
            isOneToOne: false
            referencedRelation: "sales_reps"
            referencedColumns: ["sales_rep_id"]
          },
        ]
      }
      sales_rep_custody_settlements: {
        Row: {
          cash_amount: number
          created_by: string | null
          personal_amount: number
          request_id: string
          sales_rep_id: number
          settled_at: string
          settlement_id: number
          total_amount: number
          treasury_id: number
          trip_id: number | null
        }
        Insert: {
          cash_amount?: number
          created_by?: string | null
          personal_amount?: number
          request_id: string
          sales_rep_id: number
          settled_at?: string
          settlement_id?: number
          total_amount: number
          treasury_id: number
          trip_id?: number | null
        }
        Update: {
          cash_amount?: number
          created_by?: string | null
          personal_amount?: number
          request_id?: string
          sales_rep_id?: number
          settled_at?: string
          settlement_id?: number
          total_amount?: number
          treasury_id?: number
          trip_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "sales_rep_custody_settlements_sales_rep_id_fkey"
            columns: ["sales_rep_id"]
            isOneToOne: false
            referencedRelation: "sales_reps"
            referencedColumns: ["sales_rep_id"]
          },
          {
            foreignKeyName: "sales_rep_custody_settlements_treasury_id_fkey"
            columns: ["treasury_id"]
            isOneToOne: false
            referencedRelation: "treasuries"
            referencedColumns: ["treasury_id"]
          },
          {
            foreignKeyName: "sales_rep_custody_settlements_trip_id_fkey"
            columns: ["trip_id"]
            isOneToOne: false
            referencedRelation: "trips"
            referencedColumns: ["trip_id"]
          },
        ]
      }
      sales_reps: {
        Row: {
          auth_user_id: string | null
          commission_rate: number | null
          created_at: string | null
          is_active: boolean | null
          name: string | null
          notes: string | null
          phone: string | null
          rep_code: string | null
          rep_name: string | null
          sales_rep_id: number
        }
        Insert: {
          auth_user_id?: string | null
          commission_rate?: number | null
          created_at?: string | null
          is_active?: boolean | null
          name?: string | null
          notes?: string | null
          phone?: string | null
          rep_code?: string | null
          rep_name?: string | null
          sales_rep_id?: number
        }
        Update: {
          auth_user_id?: string | null
          commission_rate?: number | null
          created_at?: string | null
          is_active?: boolean | null
          name?: string | null
          notes?: string | null
          phone?: string | null
          rep_code?: string | null
          rep_name?: string | null
          sales_rep_id?: number
        }
        Relationships: []
      }
      sales_return_exchange_items: {
        Row: {
          base_quantity: number | null
          conversion_factor: number | null
          exchange_item_id: number
          line_total: number
          location_id: number
          lot_id: number | null
          package_option_id: number | null
          package_weight_kg: number | null
          product_id: number
          quantity: number
          request_id: string | null
          sales_return_id: number
          sequence_no: number | null
          unit_id: number
          unit_price: number
        }
        Insert: {
          base_quantity?: number | null
          conversion_factor?: number | null
          exchange_item_id?: number
          line_total: number
          location_id: number
          lot_id?: number | null
          package_option_id?: number | null
          package_weight_kg?: number | null
          product_id: number
          quantity: number
          request_id?: string | null
          sales_return_id: number
          sequence_no?: number | null
          unit_id: number
          unit_price: number
        }
        Update: {
          base_quantity?: number | null
          conversion_factor?: number | null
          exchange_item_id?: number
          line_total?: number
          location_id?: number
          lot_id?: number | null
          package_option_id?: number | null
          package_weight_kg?: number | null
          product_id?: number
          quantity?: number
          request_id?: string | null
          sales_return_id?: number
          sequence_no?: number | null
          unit_id?: number
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "sales_return_exchange_items_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "sales_return_exchange_items_lot_id_fkey"
            columns: ["lot_id"]
            isOneToOne: false
            referencedRelation: "stock_lots"
            referencedColumns: ["lot_id"]
          },
          {
            foreignKeyName: "sales_return_exchange_items_package_option_id_fkey"
            columns: ["package_option_id"]
            isOneToOne: false
            referencedRelation: "product_packaging_options"
            referencedColumns: ["package_option_id"]
          },
          {
            foreignKeyName: "sales_return_exchange_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "sales_return_exchange_items_sales_return_id_fkey"
            columns: ["sales_return_id"]
            isOneToOne: false
            referencedRelation: "sales_returns"
            referencedColumns: ["sales_return_id"]
          },
          {
            foreignKeyName: "sales_return_exchange_items_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
        ]
      }
      sales_return_item_inspections: {
        Row: {
          created_at: string
          final_disposition: string | null
          finalized_at: string | null
          finalized_by: string | null
          inspection_status: string
          production_disposition: string | null
          production_inspected_at: string | null
          production_inspected_by: string | null
          production_notes: string | null
          production_rework_quantity: number
          production_scrap_quantity: number
          production_sellable_quantity: number
          received_at: string | null
          received_location_id: number | null
          return_item_id: number
          updated_at: string
          warehouse_disposition: string | null
          warehouse_inspected_at: string | null
          warehouse_inspected_by: string | null
          warehouse_notes: string | null
          warehouse_rework_quantity: number
          warehouse_scrap_quantity: number
          warehouse_sellable_quantity: number
        }
        Insert: {
          created_at?: string
          final_disposition?: string | null
          finalized_at?: string | null
          finalized_by?: string | null
          inspection_status?: string
          production_disposition?: string | null
          production_inspected_at?: string | null
          production_inspected_by?: string | null
          production_notes?: string | null
          production_rework_quantity?: number
          production_scrap_quantity?: number
          production_sellable_quantity?: number
          received_at?: string | null
          received_location_id?: number | null
          return_item_id: number
          updated_at?: string
          warehouse_disposition?: string | null
          warehouse_inspected_at?: string | null
          warehouse_inspected_by?: string | null
          warehouse_notes?: string | null
          warehouse_rework_quantity?: number
          warehouse_scrap_quantity?: number
          warehouse_sellable_quantity?: number
        }
        Update: {
          created_at?: string
          final_disposition?: string | null
          finalized_at?: string | null
          finalized_by?: string | null
          inspection_status?: string
          production_disposition?: string | null
          production_inspected_at?: string | null
          production_inspected_by?: string | null
          production_notes?: string | null
          production_rework_quantity?: number
          production_scrap_quantity?: number
          production_sellable_quantity?: number
          received_at?: string | null
          received_location_id?: number | null
          return_item_id?: number
          updated_at?: string
          warehouse_disposition?: string | null
          warehouse_inspected_at?: string | null
          warehouse_inspected_by?: string | null
          warehouse_notes?: string | null
          warehouse_rework_quantity?: number
          warehouse_scrap_quantity?: number
          warehouse_sellable_quantity?: number
        }
        Relationships: [
          {
            foreignKeyName: "sales_return_item_inspections_received_location_id_fkey"
            columns: ["received_location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "sales_return_item_inspections_return_item_id_fkey"
            columns: ["return_item_id"]
            isOneToOne: true
            referencedRelation: "sales_return_items"
            referencedColumns: ["return_item_id"]
          },
        ]
      }
      sales_return_items: {
        Row: {
          base_quantity: number | null
          conversion_factor: number | null
          discount_amount: number
          line_total: number
          location_id: number
          lot_id: number | null
          notes: string | null
          package_option_id: number | null
          package_weight_kg: number | null
          product_id: number
          quantity: number
          request_id: string | null
          return_item_id: number
          sales_return_id: number
          sequence_no: number | null
          unit_id: number
          unit_price: number
        }
        Insert: {
          base_quantity?: number | null
          conversion_factor?: number | null
          discount_amount?: number
          line_total: number
          location_id: number
          lot_id?: number | null
          notes?: string | null
          package_option_id?: number | null
          package_weight_kg?: number | null
          product_id: number
          quantity: number
          request_id?: string | null
          return_item_id?: number
          sales_return_id: number
          sequence_no?: number | null
          unit_id: number
          unit_price: number
        }
        Update: {
          base_quantity?: number | null
          conversion_factor?: number | null
          discount_amount?: number
          line_total?: number
          location_id?: number
          lot_id?: number | null
          notes?: string | null
          package_option_id?: number | null
          package_weight_kg?: number | null
          product_id?: number
          quantity?: number
          request_id?: string | null
          return_item_id?: number
          sales_return_id?: number
          sequence_no?: number | null
          unit_id?: number
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "sales_return_items_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "sales_return_items_lot_fk"
            columns: ["lot_id"]
            isOneToOne: false
            referencedRelation: "stock_lots"
            referencedColumns: ["lot_id"]
          },
          {
            foreignKeyName: "sales_return_items_package_option_id_fkey"
            columns: ["package_option_id"]
            isOneToOne: false
            referencedRelation: "product_packaging_options"
            referencedColumns: ["package_option_id"]
          },
          {
            foreignKeyName: "sales_return_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "sales_return_items_sales_return_id_fkey"
            columns: ["sales_return_id"]
            isOneToOne: false
            referencedRelation: "sales_returns"
            referencedColumns: ["sales_return_id"]
          },
          {
            foreignKeyName: "sales_return_items_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["unit_id"]
          },
        ]
      }
      sales_returns: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          cancellation_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          cash_action: string | null
          created_at: string | null
          created_by: string | null
          customer_id: number
          discount_amount: number
          net_total: number
          notes: string | null
          price_difference: number | null
          reason: string | null
          request_id: string | null
          return_date: string | null
          return_number: string
          return_type: string
          sales_invoice_id: number | null
          sales_rep_id: number | null
          sales_return_id: number
          status: string | null
          subtotal: number
          total_exchange_value: number | null
          total_returned_value: number | null
          treasury_id: number | null
          trip_id: number | null
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cash_action?: string | null
          created_at?: string | null
          created_by?: string | null
          customer_id: number
          discount_amount?: number
          net_total?: number
          notes?: string | null
          price_difference?: number | null
          reason?: string | null
          request_id?: string | null
          return_date?: string | null
          return_number: string
          return_type: string
          sales_invoice_id?: number | null
          sales_rep_id?: number | null
          sales_return_id?: number
          status?: string | null
          subtotal?: number
          total_exchange_value?: number | null
          total_returned_value?: number | null
          treasury_id?: number | null
          trip_id?: number | null
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cash_action?: string | null
          created_at?: string | null
          created_by?: string | null
          customer_id?: number
          discount_amount?: number
          net_total?: number
          notes?: string | null
          price_difference?: number | null
          reason?: string | null
          request_id?: string | null
          return_date?: string | null
          return_number?: string
          return_type?: string
          sales_invoice_id?: number | null
          sales_rep_id?: number | null
          sales_return_id?: number
          status?: string | null
          subtotal?: number
          total_exchange_value?: number | null
          total_returned_value?: number | null
          treasury_id?: number | null
          trip_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "sales_returns_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["customer_id"]
          },
          {
            foreignKeyName: "sales_returns_sales_invoice_id_fkey"
            columns: ["sales_invoice_id"]
            isOneToOne: false
            referencedRelation: "sales_invoices"
            referencedColumns: ["sales_invoice_id"]
          },
          {
            foreignKeyName: "sales_returns_sales_rep_id_fkey"
            columns: ["sales_rep_id"]
            isOneToOne: false
            referencedRelation: "sales_reps"
            referencedColumns: ["sales_rep_id"]
          },
          {
            foreignKeyName: "sales_returns_treasury_id_fkey"
            columns: ["treasury_id"]
            isOneToOne: false
            referencedRelation: "treasuries"
            referencedColumns: ["treasury_id"]
          },
          {
            foreignKeyName: "sales_returns_trip_id_fkey"
            columns: ["trip_id"]
            isOneToOne: false
            referencedRelation: "trips"
            referencedColumns: ["trip_id"]
          },
        ]
      }
      stock_balances: {
        Row: {
          average_unit_cost: number
          balance_id: number
          inventory_value: number
          location_id: number
          product_id: number
          quantity: number
          updated_at: string
        }
        Insert: {
          average_unit_cost?: number
          balance_id?: number
          inventory_value?: number
          location_id: number
          product_id: number
          quantity?: number
          updated_at?: string
        }
        Update: {
          average_unit_cost?: number
          balance_id?: number
          inventory_value?: number
          location_id?: number
          product_id?: number
          quantity?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_balances_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "stock_balances_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
        ]
      }
      stock_lot_balances: {
        Row: {
          location_id: number
          lot_balance_id: number
          lot_id: number
          quantity: number
          updated_at: string
        }
        Insert: {
          location_id: number
          lot_balance_id?: number
          lot_id: number
          quantity?: number
          updated_at?: string
        }
        Update: {
          location_id?: number
          lot_balance_id?: number
          lot_id?: number
          quantity?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_lot_balances_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "stock_lot_balances_lot_id_fkey"
            columns: ["lot_id"]
            isOneToOne: false
            referencedRelation: "stock_lots"
            referencedColumns: ["lot_id"]
          },
        ]
      }
      stock_lots: {
        Row: {
          created_at: string
          created_by: string | null
          expires_on: string | null
          lot_code: string
          lot_id: number
          manufactured_on: string | null
          notes: string | null
          product_id: number
          received_at: string
          source_production_order_id: number | null
          source_purchase_invoice_item_id: number | null
          source_type: string
          status: string
          supplier_id: number | null
          supplier_lot_code: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          expires_on?: string | null
          lot_code?: string
          lot_id?: number
          manufactured_on?: string | null
          notes?: string | null
          product_id: number
          received_at?: string
          source_production_order_id?: number | null
          source_purchase_invoice_item_id?: number | null
          source_type: string
          status?: string
          supplier_id?: number | null
          supplier_lot_code?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          expires_on?: string | null
          lot_code?: string
          lot_id?: number
          manufactured_on?: string | null
          notes?: string | null
          product_id?: number
          received_at?: string
          source_production_order_id?: number | null
          source_purchase_invoice_item_id?: number | null
          source_type?: string
          status?: string
          supplier_id?: number | null
          supplier_lot_code?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_lots_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "stock_lots_source_production_order_id_fkey"
            columns: ["source_production_order_id"]
            isOneToOne: false
            referencedRelation: "production_orders"
            referencedColumns: ["order_id"]
          },
          {
            foreignKeyName: "stock_lots_source_purchase_invoice_item_id_fkey"
            columns: ["source_purchase_invoice_item_id"]
            isOneToOne: true
            referencedRelation: "purchase_invoice_items"
            referencedColumns: ["item_id"]
          },
          {
            foreignKeyName: "stock_lots_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["supplier_id"]
          },
        ]
      }
      stock_movement_lot_allocations: {
        Row: {
          allocation_direction: string
          allocation_id: number
          created_at: string
          lot_id: number
          movement_id: number
          quantity: number
        }
        Insert: {
          allocation_direction: string
          allocation_id?: number
          created_at?: string
          lot_id: number
          movement_id: number
          quantity: number
        }
        Update: {
          allocation_direction?: string
          allocation_id?: number
          created_at?: string
          lot_id?: number
          movement_id?: number
          quantity?: number
        }
        Relationships: [
          {
            foreignKeyName: "stock_movement_lot_allocations_lot_id_fkey"
            columns: ["lot_id"]
            isOneToOne: false
            referencedRelation: "stock_lots"
            referencedColumns: ["lot_id"]
          },
          {
            foreignKeyName: "stock_movement_lot_allocations_movement_id_fkey"
            columns: ["movement_id"]
            isOneToOne: false
            referencedRelation: "stock_movements"
            referencedColumns: ["movement_id"]
          },
        ]
      }
      stock_movements: {
        Row: {
          created_at: string
          created_by: string | null
          location_id: number
          movement_id: number
          movement_type: string
          notes: string | null
          product_id: number
          production_order_id: number | null
          production_order_material_id: number | null
          purchase_invoice_id: number | null
          purchase_return_id: number | null
          quantity_after: number
          quantity_change: number
          reversal_of_movement_id: number | null
          sales_invoice_id: number | null
          sales_invoice_item_id: number | null
          sales_return_id: number | null
          sales_return_item_id: number | null
          stock_transfer_id: number | null
          total_cost: number | null
          trip_id: number | null
          trip_load_id: number | null
          unit_cost: number | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          location_id: number
          movement_id?: number
          movement_type: string
          notes?: string | null
          product_id: number
          production_order_id?: number | null
          production_order_material_id?: number | null
          purchase_invoice_id?: number | null
          purchase_return_id?: number | null
          quantity_after: number
          quantity_change: number
          reversal_of_movement_id?: number | null
          sales_invoice_id?: number | null
          sales_invoice_item_id?: number | null
          sales_return_id?: number | null
          sales_return_item_id?: number | null
          stock_transfer_id?: number | null
          total_cost?: number | null
          trip_id?: number | null
          trip_load_id?: number | null
          unit_cost?: number | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          location_id?: number
          movement_id?: number
          movement_type?: string
          notes?: string | null
          product_id?: number
          production_order_id?: number | null
          production_order_material_id?: number | null
          purchase_invoice_id?: number | null
          purchase_return_id?: number | null
          quantity_after?: number
          quantity_change?: number
          reversal_of_movement_id?: number | null
          sales_invoice_id?: number | null
          sales_invoice_item_id?: number | null
          sales_return_id?: number | null
          sales_return_item_id?: number | null
          stock_transfer_id?: number | null
          total_cost?: number | null
          trip_id?: number | null
          trip_load_id?: number | null
          unit_cost?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_movements_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "stock_movements_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "stock_movements_production_material_order_fkey"
            columns: ["production_order_id", "production_order_material_id"]
            isOneToOne: false
            referencedRelation: "production_order_materials"
            referencedColumns: ["order_id", "material_id"]
          },
          {
            foreignKeyName: "stock_movements_production_order_id_fkey"
            columns: ["production_order_id"]
            isOneToOne: false
            referencedRelation: "production_orders"
            referencedColumns: ["order_id"]
          },
          {
            foreignKeyName: "stock_movements_purchase_invoice_fk"
            columns: ["purchase_invoice_id"]
            isOneToOne: false
            referencedRelation: "purchase_invoices"
            referencedColumns: ["purchase_invoice_id"]
          },
          {
            foreignKeyName: "stock_movements_purchase_return_fk"
            columns: ["purchase_return_id"]
            isOneToOne: false
            referencedRelation: "purchase_returns"
            referencedColumns: ["return_id"]
          },
          {
            foreignKeyName: "stock_movements_reversal_movement_fk"
            columns: ["reversal_of_movement_id"]
            isOneToOne: false
            referencedRelation: "stock_movements"
            referencedColumns: ["movement_id"]
          },
          {
            foreignKeyName: "stock_movements_sales_invoice_id_fkey"
            columns: ["sales_invoice_id"]
            isOneToOne: false
            referencedRelation: "sales_invoices"
            referencedColumns: ["sales_invoice_id"]
          },
          {
            foreignKeyName: "stock_movements_sales_invoice_item_id_fkey"
            columns: ["sales_invoice_item_id"]
            isOneToOne: false
            referencedRelation: "sales_invoice_items"
            referencedColumns: ["sales_invoice_item_id"]
          },
          {
            foreignKeyName: "stock_movements_sales_return_id_fkey"
            columns: ["sales_return_id"]
            isOneToOne: false
            referencedRelation: "sales_returns"
            referencedColumns: ["sales_return_id"]
          },
          {
            foreignKeyName: "stock_movements_sales_return_item_id_fkey"
            columns: ["sales_return_item_id"]
            isOneToOne: false
            referencedRelation: "sales_return_items"
            referencedColumns: ["return_item_id"]
          },
          {
            foreignKeyName: "stock_movements_stock_transfer_id_fkey"
            columns: ["stock_transfer_id"]
            isOneToOne: false
            referencedRelation: "stock_transfers"
            referencedColumns: ["transfer_id"]
          },
          {
            foreignKeyName: "stock_movements_trip_id_fkey"
            columns: ["trip_id"]
            isOneToOne: false
            referencedRelation: "trips"
            referencedColumns: ["trip_id"]
          },
          {
            foreignKeyName: "stock_movements_trip_load_id_fkey"
            columns: ["trip_load_id"]
            isOneToOne: false
            referencedRelation: "trip_loads"
            referencedColumns: ["load_id"]
          },
        ]
      }
      stock_transfer_items: {
        Row: {
          item_id: number
          product_id: number | null
          quantity: number
          transfer_id: number | null
        }
        Insert: {
          item_id?: number
          product_id?: number | null
          quantity: number
          transfer_id?: number | null
        }
        Update: {
          item_id?: number
          product_id?: number | null
          quantity?: number
          transfer_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_transfer_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "stock_transfer_items_transfer_id_fkey"
            columns: ["transfer_id"]
            isOneToOne: false
            referencedRelation: "stock_transfers"
            referencedColumns: ["transfer_id"]
          },
        ]
      }
      stock_transfer_reversals: {
        Row: {
          original_transfer_id: number
          reason: string
          request_id: string
          reversal_id: number
          reversal_transfer_id: number
          reversed_at: string
          reversed_by: string
        }
        Insert: {
          original_transfer_id: number
          reason: string
          request_id: string
          reversal_id?: number
          reversal_transfer_id: number
          reversed_at?: string
          reversed_by: string
        }
        Update: {
          original_transfer_id?: number
          reason?: string
          request_id?: string
          reversal_id?: number
          reversal_transfer_id?: number
          reversed_at?: string
          reversed_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_transfer_reversals_original_transfer_id_fkey"
            columns: ["original_transfer_id"]
            isOneToOne: true
            referencedRelation: "stock_transfers"
            referencedColumns: ["transfer_id"]
          },
          {
            foreignKeyName: "stock_transfer_reversals_reversal_transfer_id_fkey"
            columns: ["reversal_transfer_id"]
            isOneToOne: true
            referencedRelation: "stock_transfers"
            referencedColumns: ["transfer_id"]
          },
        ]
      }
      stock_transfers: {
        Row: {
          created_at: string | null
          created_by: string | null
          destination_location_id: number | null
          notes: string | null
          request_id: string | null
          source_location_id: number | null
          transfer_date: string
          transfer_id: number
          transfer_number: string
        }
        Insert: {
          created_at?: string | null
          created_by?: string | null
          destination_location_id?: number | null
          notes?: string | null
          request_id?: string | null
          source_location_id?: number | null
          transfer_date: string
          transfer_id?: number
          transfer_number: string
        }
        Update: {
          created_at?: string | null
          created_by?: string | null
          destination_location_id?: number | null
          notes?: string | null
          request_id?: string | null
          source_location_id?: number | null
          transfer_date?: string
          transfer_id?: number
          transfer_number?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_transfers_destination_location_id_fkey"
            columns: ["destination_location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "stock_transfers_source_location_id_fkey"
            columns: ["source_location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
        ]
      }
      supplier_payments: {
        Row: {
          amount: number
          cancelled_at: string | null
          cancelled_by: string | null
          created_at: string | null
          created_by: string | null
          is_cancelled: boolean
          notes: string | null
          payment_date: string
          payment_id: number
          request_id: string | null
          supplier_id: number | null
          treasury_id: number | null
        }
        Insert: {
          amount: number
          cancelled_at?: string | null
          cancelled_by?: string | null
          created_at?: string | null
          created_by?: string | null
          is_cancelled?: boolean
          notes?: string | null
          payment_date: string
          payment_id?: number
          request_id?: string | null
          supplier_id?: number | null
          treasury_id?: number | null
        }
        Update: {
          amount?: number
          cancelled_at?: string | null
          cancelled_by?: string | null
          created_at?: string | null
          created_by?: string | null
          is_cancelled?: boolean
          notes?: string | null
          payment_date?: string
          payment_id?: number
          request_id?: string | null
          supplier_id?: number | null
          treasury_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "supplier_payments_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["supplier_id"]
          },
          {
            foreignKeyName: "supplier_payments_treasury_id_fkey"
            columns: ["treasury_id"]
            isOneToOne: false
            referencedRelation: "treasuries"
            referencedColumns: ["treasury_id"]
          },
        ]
      }
      suppliers: {
        Row: {
          address: string | null
          created_at: string
          is_active: boolean
          notes: string | null
          opening_balance: number
          phone: string | null
          supplier_code: string
          supplier_id: number
          supplier_name: string
          tax_number: string | null
          updated_at: string
        }
        Insert: {
          address?: string | null
          created_at?: string
          is_active?: boolean
          notes?: string | null
          opening_balance?: number
          phone?: string | null
          supplier_code: string
          supplier_id?: number
          supplier_name: string
          tax_number?: string | null
          updated_at?: string
        }
        Update: {
          address?: string | null
          created_at?: string
          is_active?: boolean
          notes?: string | null
          opening_balance?: number
          phone?: string | null
          supplier_code?: string
          supplier_id?: number
          supplier_name?: string
          tax_number?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      treasuries: {
        Row: {
          account_id: number | null
          created_at: string | null
          created_by: string | null
          current_balance: number
          is_active: boolean
          notes: string | null
          opening_balance: number
          treasury_id: number
          treasury_name: string
          treasury_type: string
        }
        Insert: {
          account_id?: number | null
          created_at?: string | null
          created_by?: string | null
          current_balance?: number
          is_active?: boolean
          notes?: string | null
          opening_balance?: number
          treasury_id?: number
          treasury_name: string
          treasury_type: string
        }
        Update: {
          account_id?: number | null
          created_at?: string | null
          created_by?: string | null
          current_balance?: number
          is_active?: boolean
          notes?: string | null
          opening_balance?: number
          treasury_id?: number
          treasury_name?: string
          treasury_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "treasuries_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "chart_of_accounts"
            referencedColumns: ["account_id"]
          },
        ]
      }
      treasury_transactions: {
        Row: {
          amount: number
          created_at: string | null
          created_by: string | null
          notes: string | null
          reference_id: number | null
          reference_type: string | null
          request_id: string | null
          transaction_date: string
          transaction_id: number
          transaction_type: string
          treasury_id: number
        }
        Insert: {
          amount: number
          created_at?: string | null
          created_by?: string | null
          notes?: string | null
          reference_id?: number | null
          reference_type?: string | null
          request_id?: string | null
          transaction_date?: string
          transaction_id?: number
          transaction_type: string
          treasury_id: number
        }
        Update: {
          amount?: number
          created_at?: string | null
          created_by?: string | null
          notes?: string | null
          reference_id?: number | null
          reference_type?: string | null
          request_id?: string | null
          transaction_date?: string
          transaction_id?: number
          transaction_type?: string
          treasury_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "treasury_transactions_treasury_id_fkey"
            columns: ["treasury_id"]
            isOneToOne: false
            referencedRelation: "treasuries"
            referencedColumns: ["treasury_id"]
          },
        ]
      }
      trip_customers: {
        Row: {
          assigned_at: string
          assigned_by: string | null
          customer_id: number
          notes: string | null
          trip_customer_id: number
          trip_id: number
        }
        Insert: {
          assigned_at?: string
          assigned_by?: string | null
          customer_id: number
          notes?: string | null
          trip_customer_id?: number
          trip_id: number
        }
        Update: {
          assigned_at?: string
          assigned_by?: string | null
          customer_id?: number
          notes?: string | null
          trip_customer_id?: number
          trip_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "trip_customers_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["customer_id"]
          },
          {
            foreignKeyName: "trip_customers_trip_id_fkey"
            columns: ["trip_id"]
            isOneToOne: false
            referencedRelation: "trips"
            referencedColumns: ["trip_id"]
          },
        ]
      }
      trip_loads: {
        Row: {
          actual_package_count: number | null
          approved_quantity: number | null
          approved_weight_kg: number | null
          created_at: string
          load_id: number
          load_status: string
          package_option_id: number | null
          package_weight_kg: number | null
          product_id: number
          quantity_loaded: number
          quantity_returned: number
          quantity_sold: number
          requested_quantity: number
          requested_weight_kg: number | null
          trip_id: number
        }
        Insert: {
          actual_package_count?: number | null
          approved_quantity?: number | null
          approved_weight_kg?: number | null
          created_at?: string
          load_id?: number
          load_status?: string
          package_option_id?: number | null
          package_weight_kg?: number | null
          product_id: number
          quantity_loaded: number
          quantity_returned?: number
          quantity_sold?: number
          requested_quantity?: number
          requested_weight_kg?: number | null
          trip_id: number
        }
        Update: {
          actual_package_count?: number | null
          approved_quantity?: number | null
          approved_weight_kg?: number | null
          created_at?: string
          load_id?: number
          load_status?: string
          package_option_id?: number | null
          package_weight_kg?: number | null
          product_id?: number
          quantity_loaded?: number
          quantity_returned?: number
          quantity_sold?: number
          requested_quantity?: number
          requested_weight_kg?: number | null
          trip_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "trip_loads_package_option_id_fkey"
            columns: ["package_option_id"]
            isOneToOne: false
            referencedRelation: "product_packaging_options"
            referencedColumns: ["package_option_id"]
          },
          {
            foreignKeyName: "trip_loads_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "trip_loads_trip_id_fkey"
            columns: ["trip_id"]
            isOneToOne: false
            referencedRelation: "trips"
            referencedColumns: ["trip_id"]
          },
        ]
      }
      trips: {
        Row: {
          created_at: string
          created_by: string | null
          end_date: string | null
          initial_cash: number | null
          notes: string | null
          request_id: string | null
          sales_rep_id: number
          source_location_id: number | null
          start_date: string
          status: string
          trip_id: number
          trip_number: string
          updated_at: string
          vehicle_location_id: number
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          end_date?: string | null
          initial_cash?: number | null
          notes?: string | null
          request_id?: string | null
          sales_rep_id: number
          source_location_id?: number | null
          start_date?: string
          status?: string
          trip_id?: number
          trip_number: string
          updated_at?: string
          vehicle_location_id: number
        }
        Update: {
          created_at?: string
          created_by?: string | null
          end_date?: string | null
          initial_cash?: number | null
          notes?: string | null
          request_id?: string | null
          sales_rep_id?: number
          source_location_id?: number | null
          start_date?: string
          status?: string
          trip_id?: number
          trip_number?: string
          updated_at?: string
          vehicle_location_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "trips_sales_rep_id_fkey"
            columns: ["sales_rep_id"]
            isOneToOne: false
            referencedRelation: "sales_reps"
            referencedColumns: ["sales_rep_id"]
          },
          {
            foreignKeyName: "trips_source_location_id_fkey"
            columns: ["source_location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
          {
            foreignKeyName: "trips_vehicle_location_id_fkey"
            columns: ["vehicle_location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["location_id"]
          },
        ]
      }
      units: {
        Row: {
          allows_decimal: boolean
          conversion_to_kg: number | null
          created_at: string
          decimal_places: number
          is_active: boolean
          is_package_unit: boolean
          unit_code: string
          unit_id: number
          unit_name: string
          unit_type: string
        }
        Insert: {
          allows_decimal?: boolean
          conversion_to_kg?: number | null
          created_at?: string
          decimal_places?: number
          is_active?: boolean
          is_package_unit?: boolean
          unit_code: string
          unit_id?: number
          unit_name: string
          unit_type: string
        }
        Update: {
          allows_decimal?: boolean
          conversion_to_kg?: number | null
          created_at?: string
          decimal_places?: number
          is_active?: boolean
          is_package_unit?: boolean
          unit_code?: string
          unit_id?: number
          unit_name?: string
          unit_type?: string
        }
        Relationships: []
      }
      user_logs: {
        Row: {
          action_type: string | null
          created_at: string | null
          description: string | null
          entity_id: number | null
          entity_type: string | null
          log_id: number
          request_id: string | null
          user_id: string | null
        }
        Insert: {
          action_type?: string | null
          created_at?: string | null
          description?: string | null
          entity_id?: number | null
          entity_type?: string | null
          log_id?: number
          request_id?: string | null
          user_id?: string | null
        }
        Update: {
          action_type?: string | null
          created_at?: string | null
          description?: string | null
          entity_id?: number | null
          entity_type?: string | null
          log_id?: number
          request_id?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      add_production_order_extra_material: {
        Args: {
          p_order_id: number
          p_product_id: number
          p_quantity: number
          p_request_id: string
        }
        Returns: number
      }
      add_sales_return_item: {
        Args: {
          p_discount_amount: number
          p_lot_id: number
          p_notes: string
          p_package_option_id: number
          p_product_id: number
          p_quantity: number
          p_sales_return_id: number
          p_unit_id: number
          p_unit_price: number
        }
        Returns: number
      }
      add_sales_return_item_v2: {
        Args: {
          p_discount_amount: number
          p_lot_id: number
          p_notes: string
          p_package_option_id: number
          p_product_id: number
          p_quantity: number
          p_request_id: string
          p_sales_return_id: number
          p_unit_id: number
          p_unit_price: number
        }
        Returns: number
      }
      adjust_treasury_balance: {
        Args: { p_amount: number; p_notes?: string; p_treasury_id: number }
        Returns: undefined
      }
      admin_factory_reset_approve: {
        Args: { p_plan_hash: string; p_plan_id: string }
        Returns: Json
      }
      admin_factory_reset_execute: {
        Args: { p_plan_hash: string; p_plan_id: string }
        Returns: Json
      }
      admin_factory_reset_get_latest: { Args: never; Returns: Json }
      admin_factory_reset_prepare: { Args: never; Returns: Json }
      approve_price_list: {
        Args: { p_price_list_id: number }
        Returns: undefined
      }
      approve_trip_load_v2: {
        Args: { p_approved_quantity: number; p_load_id: number }
        Returns: number
      }
      assert_accounting_period_open: {
        Args: { p_entry_date: string }
        Returns: undefined
      }
      assert_stock_available: {
        Args: {
          p_location_id: number
          p_product_id: number
          p_quantity: number
        }
        Returns: undefined
      }
      bounce_customer_cheque: {
        Args: { p_cheque_id: number; p_dishonor_reason: string }
        Returns: undefined
      }
      cancel_collection: {
        Args: { p_collection_id: number }
        Returns: undefined
      }
      cancel_collection_v2: {
        Args: { p_collection_id: number; p_reason: string }
        Returns: undefined
      }
      cancel_expense: {
        Args: { p_expense_id: number; p_reason: string }
        Returns: undefined
      }
      cancel_fixed_asset_depreciation: {
        Args: {
          p_depreciation_id: number
          p_reason: string
          p_request_id: string
        }
        Returns: undefined
      }
      cancel_fixed_asset_purchase: {
        Args: {
          p_asset_id: number
          p_reason: string
          p_refund_treasury_id: number
        }
        Returns: undefined
      }
      cancel_fixed_asset_purchase_on_credit: {
        Args: { p_asset_id: number; p_reason: string }
        Returns: undefined
      }
      cancel_partner_equipment_contribution: {
        Args: {
          p_asset_id: number
          p_asset_returned_unused: boolean
          p_reason: string
        }
        Returns: undefined
      }
      cancel_partner_inventory_contribution: {
        Args: {
          p_cancellation_request_id: string
          p_contribution_id: number
          p_reason: string
          p_stock_returned_unused: boolean
        }
        Returns: undefined
      }
      cancel_partner_other_asset_contribution: {
        Args: {
          p_asset_id: number
          p_asset_returned_unused: boolean
          p_cancellation_request_id: string
          p_reason: string
        }
        Returns: undefined
      }
      cancel_partner_profit_distribution: {
        Args: {
          p_distribution_id: number
          p_reason: string
          p_request_id: string
        }
        Returns: undefined
      }
      cancel_partner_profit_payout: {
        Args: {
          p_reason: string
          p_request_id: string
          p_transaction_id: number
        }
        Returns: number
      }
      cancel_partner_vehicle_contribution: {
        Args: {
          p_asset_id: number
          p_cancellation_request_id: string
          p_reason: string
          p_vehicle_returned_unused: boolean
        }
        Returns: undefined
      }
      cancel_purchase_invoice: {
        Args: { p_invoice_id: number; p_reason: string }
        Returns: undefined
      }
      cancel_purchase_landed_cost: {
        Args: {
          p_landed_cost_id: number
          p_reason: string
          p_refund_treasury_id?: number
        }
        Returns: undefined
      }
      cancel_purchase_landed_cost_on_credit: {
        Args: { p_landed_cost_id: number; p_reason: string }
        Returns: undefined
      }
      cancel_purchase_return: {
        Args: { p_reason: string; p_return_id: number }
        Returns: undefined
      }
      cancel_sales_invoice: {
        Args: { p_invoice_id: number }
        Returns: undefined
      }
      cancel_sales_return: {
        Args: { p_reason: string; p_sales_return_id: number }
        Returns: undefined
      }
      cancel_sales_return_draft: {
        Args: { p_reason: string; p_sales_return_id: number }
        Returns: undefined
      }
      cancel_sales_return_exchange_v1: {
        Args: { p_reason: string; p_sales_return_id: number }
        Returns: undefined
      }
      cancel_sales_return_exchange_v1_internal_return_hold: {
        Args: { p_reason: string; p_sales_return_id: number }
        Returns: undefined
      }
      cancel_sales_return_internal_return_hold: {
        Args: { p_reason: string; p_sales_return_id: number }
        Returns: undefined
      }
      cancel_supplier_payment: {
        Args: { p_payment_id: number; p_reason: string }
        Returns: undefined
      }
      clear_customer_cheque: {
        Args: { p_bank_reference?: string; p_cheque_id: number }
        Returns: undefined
      }
      close_accounting_period: {
        Args: { p_notes?: string; p_period_id: number }
        Returns: undefined
      }
      configure_fixed_asset_depreciation: {
        Args: {
          p_asset_id: number
          p_depreciation_method: string
          p_residual_value: number
          p_useful_life_months: number
        }
        Returns: undefined
      }
      confirm_trip_load_dispatch: {
        Args: {
          p_actual_quantity: number
          p_created_by?: string
          p_load_id: number
        }
        Returns: number
      }
      create_accounting_period: {
        Args: {
          p_end_date: string
          p_notes?: string
          p_period_name: string
          p_start_date: string
        }
        Returns: number
      }
      create_auto_journal_entry:
        | {
            Args: {
              p_amount: number
              p_credit_account_code: string
              p_debit_account_code: string
              p_description: string
              p_entry_date: string
              p_reference_id: number
              p_reference_type: string
            }
            Returns: undefined
          }
        | {
            Args: {
              p_amount: number
              p_credit_account_code: string
              p_debit_account_code: string
              p_description: string
              p_entry_date: string
              p_reference_id: number
              p_reference_type: string
            }
            Returns: undefined
          }
      create_cheque_collection: {
        Args: {
          p_amount: number
          p_bank_name: string
          p_cheque_number: string
          p_collection_date: string
          p_customer_id: number
          p_due_date: string
          p_notes: string
          p_sales_invoice_id: number
          p_trip_id: number
        }
        Returns: number
      }
      create_collection_v3:
        | {
            Args: {
              p_amount: number
              p_bank_name: string
              p_collection_date: string
              p_customer_id: number
              p_due_date: string
              p_notes: string
              p_payment_method: string
              p_reference_number: string
              p_sales_invoice_id: number
              p_treasury_id: number
              p_trip_id: number
            }
            Returns: number
          }
        | {
            Args: {
              p_amount: number
              p_bank_name: string
              p_collection_date: string
              p_customer_id: number
              p_due_date: string
              p_notes: string
              p_payment_method: string
              p_reference_number: string
              p_request_id: string
              p_sales_invoice_id: number
              p_treasury_id: number
              p_trip_id: number
            }
            Returns: number
          }
      create_collection_v4: {
        Args: {
          p_amount: number
          p_bank_name: string
          p_collection_date: string
          p_customer_id: number
          p_due_date: string
          p_notes: string
          p_payment_method: string
          p_receipt_destination: string
          p_reference_number: string
          p_request_id: string
          p_sales_invoice_id: number
          p_treasury_id: number
          p_trip_id: number
        }
        Returns: number
      }
      create_expense: {
        Args: {
          p_amount: number
          p_expense_date: string
          p_expense_type: string
          p_notes: string
          p_treasury_id: number
          p_trip_id?: number
        }
        Returns: number
      }
      create_expense_v2: {
        Args: {
          p_amount: number
          p_expense_date: string
          p_expense_type: string
          p_notes: string
          p_request_id: string
          p_treasury_id: number
          p_trip_id: number
        }
        Returns: number
      }
      create_fixed_asset_purchase: {
        Args: {
          p_acquisition_date: string
          p_amount: number
          p_asset_name: string
          p_location_description?: string
          p_notes?: string
          p_request_id?: string
          p_serial_number?: string
          p_treasury_id: number
        }
        Returns: number
      }
      create_fixed_asset_purchase_on_credit: {
        Args: {
          p_acquisition_date: string
          p_amount: number
          p_asset_name: string
          p_location_description?: string
          p_notes?: string
          p_request_id?: string
          p_serial_number?: string
          p_supplier_id: number
        }
        Returns: number
      }
      create_fixed_asset_purchase_v2: {
        Args: {
          p_acquisition_date: string
          p_amount: number
          p_asset_name: string
          p_location_description?: string
          p_notes?: string
          p_request_id?: string
          p_serial_number?: string
          p_treasury_id: number
        }
        Returns: number
      }
      create_manual_journal_adjustment: {
        Args: {
          p_amount: number
          p_credit_account: string
          p_debit_account: string
          p_description: string
          p_entry_date: string
          p_request_id: string
        }
        Returns: Json
      }
      create_notification: {
        Args: {
          p_body: string
          p_due_at?: string
          p_entity_id?: string
          p_entity_type?: string
          p_event_key: string
          p_metadata?: Json
          p_notification_type: string
          p_title: string
          p_user_ids: string[]
        }
        Returns: string
      }
      create_partner_equipment_contribution: {
        Args: {
          p_acquisition_date: string
          p_amount: number
          p_asset_name: string
          p_location_description: string
          p_notes: string
          p_partner_id: number
          p_request_id: string
          p_serial_number: string
        }
        Returns: number
      }
      create_partner_inventory_contribution: {
        Args: {
          p_contribution_date: string
          p_location_id: number
          p_notes: string
          p_partner_id: number
          p_product_id: number
          p_quantity: number
          p_request_id: string
          p_total_value: number
          p_unit_id: number
        }
        Returns: number
      }
      create_partner_other_asset_contribution: {
        Args: {
          p_acquisition_date: string
          p_amount: number
          p_asset_category: string
          p_asset_name: string
          p_location_description: string
          p_notes: string
          p_partner_id: number
          p_request_id: string
          p_serial_number: string
        }
        Returns: number
      }
      create_partner_profit_distribution: {
        Args: { p_from: string; p_request_id: string; p_to: string }
        Returns: number
      }
      create_partner_transaction: {
        Args: {
          p_amount: number
          p_notes?: string
          p_partner_id: number
          p_transaction_date: string
          p_transaction_type: string
          p_treasury_id?: number
        }
        Returns: number
      }
      create_partner_transaction_v2: {
        Args: {
          p_amount: number
          p_notes: string
          p_partner_id: number
          p_request_id: string
          p_transaction_date: string
          p_transaction_type: string
          p_treasury_id: number
        }
        Returns: number
      }
      create_partner_vehicle_contribution: {
        Args: {
          p_acquisition_date: string
          p_amount: number
          p_location_description: string
          p_notes: string
          p_partner_id: number
          p_plate_number: string
          p_request_id: string
          p_vehicle_name: string
        }
        Returns: number
      }
      create_production_order: {
        Args: {
          p_location_id: number
          p_notes?: string
          p_recipe_id: number
          p_target_quantity: number
        }
        Returns: string
      }
      create_production_order_v2: {
        Args: {
          p_location_id: number
          p_notes: string
          p_recipe_id: number
          p_request_id: string
          p_target_quantity: number
        }
        Returns: string
      }
      create_purchase_invoice: {
        Args: {
          p_discount: number
          p_invoice_date: string
          p_items: Json
          p_location_id: number
          p_notes: string
          p_request_id: string
          p_supplier_id: number
          p_treasury_id: number
        }
        Returns: number
      }
      create_purchase_landed_cost: {
        Args: {
          p_amount: number
          p_expense_id?: number
          p_invoice_id: number
          p_notes?: string
          p_request_id?: string
          p_source_type: string
          p_treasury_id?: number
        }
        Returns: number
      }
      create_purchase_landed_cost_on_credit: {
        Args: {
          p_amount: number
          p_cost_date: string
          p_invoice_id: number
          p_notes?: string
          p_request_id: string
          p_supplier_id: number
        }
        Returns: number
      }
      create_purchase_landed_cost_v2: {
        Args: {
          p_amount: number
          p_expense_id?: number
          p_invoice_id: number
          p_notes?: string
          p_request_id?: string
          p_source_type: string
          p_treasury_id?: number
        }
        Returns: number
      }
      create_purchase_return: {
        Args: {
          p_items: Json
          p_notes?: string
          p_purchase_invoice_id: number
          p_request_id?: string
          p_return_date: string
          p_settlement_method?: string
          p_supplier_id: number
          p_treasury_id?: number
        }
        Returns: number
      }
      create_reservation_v2: {
        Args: {
          p_customer_id: number
          p_location_id: number
          p_notes: string
          p_product_id: number
          p_quantity: number
          p_request_id: string
          p_reserved_until: string
        }
        Returns: number
      }
      create_sales_invoice_v2:
        | {
            Args: {
              p_customer_id: number
              p_discount: number
              p_invoice_date: string
              p_items: Json
              p_location_id: number
              p_notes: string
              p_payments: Json
              p_trip_id: number
            }
            Returns: number
          }
        | {
            Args: {
              p_customer_id: number
              p_discount: number
              p_invoice_date: string
              p_items: Json
              p_location_id: number
              p_notes: string
              p_payments: Json
              p_request_id: string
              p_trip_id: number
            }
            Returns: number
          }
      create_sales_return: {
        Args: {
          p_cash_action: string
          p_created_by: string
          p_customer_id: number
          p_notes: string
          p_reason: string
          p_return_date: string
          p_return_number: string
          p_return_type: string
          p_sales_invoice_id: number
          p_sales_rep_id: number
          p_treasury_id: number
          p_trip_id: number
        }
        Returns: number
      }
      create_sales_return_exchange_v1: {
        Args: {
          p_cash_action: string
          p_created_by: string
          p_customer_id: number
          p_exchange_items: Json
          p_notes: string
          p_reason: string
          p_request_id: string
          p_return_date: string
          p_return_items: Json
          p_return_number: string
          p_sales_invoice_id: number
          p_sales_rep_id: number
          p_treasury_id: number
          p_trip_id: number
        }
        Returns: number
      }
      create_sales_return_v2: {
        Args: {
          p_cash_action: string
          p_created_by: string
          p_customer_id: number
          p_notes: string
          p_reason: string
          p_request_id: string
          p_return_date: string
          p_return_number: string
          p_return_type: string
          p_sales_invoice_id: number
          p_sales_rep_id: number
          p_treasury_id: number
          p_trip_id: number
        }
        Returns: number
      }
      create_stock_transfer:
        | {
            Args: {
              p_destination_location_id: number
              p_items: Json
              p_notes: string
              p_source_location_id: number
              p_transfer_date: string
            }
            Returns: number
          }
        | {
            Args: {
              p_destination_location_id: number
              p_items: Json
              p_notes: string
              p_request_id: string
              p_source_location_id: number
              p_transfer_date: string
            }
            Returns: number
          }
      create_stock_transfer_internal_legacy_return_hold: {
        Args: {
          p_destination_location_id: number
          p_items: Json
          p_notes?: string
          p_source_location_id: number
          p_transfer_date: string
        }
        Returns: number
      }
      create_stock_transfer_internal_return_rework: {
        Args: {
          p_destination_location_id: number
          p_items: Json
          p_notes: string
          p_request_id: string
          p_source_location_id: number
          p_transfer_date: string
        }
        Returns: number
      }
      create_supplier_payment: {
        Args: {
          p_amount: number
          p_notes: string
          p_payment_date: string
          p_request_id: string
          p_supplier_id: number
          p_treasury_id: number
        }
        Returns: number
      }
      create_trip: {
        Args: {
          p_initial_cash?: number
          p_notes?: string
          p_sales_rep_id: number
          p_source_location_id: number
          p_trip_date: string
          p_vehicle_location_id: number
        }
        Returns: number
      }
      create_trip_v2: {
        Args: {
          p_initial_cash?: number
          p_notes?: string
          p_request_id?: string
          p_sales_rep_id: number
          p_source_location_id: number
          p_trip_date: string
          p_vehicle_location_id: number
        }
        Returns: number
      }
      delete_sales_order_item: {
        Args: { p_sales_order_item_id: number }
        Returns: undefined
      }
      dispose_fixed_asset:
        | {
            Args: {
              p_asset_id: number
              p_disposal_date: string
              p_proceeds: number
              p_reason: string
              p_request_id: string
            }
            Returns: number
          }
        | {
            Args: {
              p_asset_id: number
              p_disposal_date: string
              p_disposal_treasury_id: number
              p_proceeds: number
              p_reason: string
              p_request_id: string
            }
            Returns: number
          }
      execute_production_order_v2: {
        Args: {
          p_actual_output_quantity: number
          p_materials: Json
          p_order_id: number
        }
        Returns: Json
      }
      execute_production_order_v3: {
        Args: {
          p_abnormal_waste_cost: number
          p_actual_output_quantity: number
          p_materials: Json
          p_order_id: number
          p_recovered_materials: Json
        }
        Returns: Json
      }
      execute_production_order_v4: {
        Args: {
          p_abnormal_waste: Json
          p_actual_output_quantity: number
          p_execution_date: string
          p_materials: Json
          p_order_id: number
          p_recovered_materials: Json
        }
        Returns: Json
      }
      execute_production_order_v6: {
        Args: {
          p_abnormal_waste: Json
          p_actual_output_quantity: number
          p_direct_expenses: Json
          p_execution_date: string
          p_materials: Json
          p_order_id: number
          p_recovered_materials: Json
        }
        Returns: Json
      }
      execute_production_order_v6_internal_return_rework: {
        Args: {
          p_abnormal_waste: Json
          p_actual_output_quantity: number
          p_direct_expenses: Json
          p_execution_date: string
          p_materials: Json
          p_order_id: number
          p_recovered_materials: Json
        }
        Returns: Json
      }
      fn_base_factor: {
        Args: { p_product_id: number; p_unit_id: number }
        Returns: number
      }
      fn_get_product_unit_conversion: {
        Args: { p_product_id: number; p_unit_id: number }
        Returns: number
      }
      generate_due_invoice_notifications: { Args: never; Returns: number }
      generate_lot_expiry_notifications: { Args: never; Returns: number }
      get_account_ledger: {
        Args: { p_account_id: number; p_from: string; p_to: string }
        Returns: {
          credit: number
          debit: number
          description: string
          entry_date: string
          entry_id: number
          entry_number: string
          line_description: string
          running_balance: number
        }[]
      }
      get_accounting_period_closure: {
        Args: { p_period_id: number }
        Returns: {
          closed_at: string
          closing_entry_id: number
          cogs_amount: number
          end_date: string
          expenses_amount: number
          period_id: number
          period_name: string
          profit_amount: number
          revenue_amount: number
          start_date: string
        }[]
      }
      get_aged_receivables: {
        Args: never
        Returns: {
          current_balance: number
          customer_name: string
          days_0_30: number
          days_31_60: number
          days_61_90: number
          days_over_90: number
          phone: string
        }[]
      }
      get_aged_receivables_v2: {
        Args: never
        Returns: {
          current_balance: number
          customer_name: string
          days_0_30: number
          days_31_60: number
          days_61_90: number
          days_over_90: number
          opening_balance: number
          phone: string
        }[]
      }
      get_available_production_expenses: {
        Args: { p_order_id: number }
        Returns: {
          account_code: string
          account_id: number
          allocated_amount: number
          amount: number
          available_amount: number
          expense_date: string
          expense_id: number
          expense_type: string
        }[]
      }
      get_current_sales_rep_id: { Args: never; Returns: number }
      get_current_user_role: { Args: never; Returns: string }
      get_customer_credit_balance_v1: {
        Args: { p_customer_id: number }
        Returns: number
      }
      get_customer_price_list: {
        Args: { p_as_of_date?: string; p_customer_id: number }
        Returns: {
          price_list_code: string
          price_list_id: number
          price_list_name: string
          priority: number
          source_type: string
          valid_from: string
          valid_to: string
        }[]
      }
      get_customer_product_price: {
        Args: {
          p_as_of_date?: string
          p_customer_id: number
          p_product_id: number
          p_unit_id: number
        }
        Returns: {
          maximum_price: number
          minimum_price: number
          price_list_code: string
          price_list_id: number
          product_code: string
          product_id: number
          product_name: string
          selling_price: number
          unit_code: string
          unit_id: number
        }[]
      }
      get_customer_returns: { Args: { p_customer_id: number }; Returns: Json }
      get_financial_summary: { Args: never; Returns: Json }
      get_journal_entries: {
        Args: { p_from: string; p_to: string }
        Returns: {
          account_name: string
          credit: number
          debit: number
          description: string
          entry_date: string
        }[]
      }
      get_journal_entries_full: {
        Args: { p_from: string; p_to: string }
        Returns: {
          account_code: string
          account_name: string
          credit: number
          debit: number
          description: string
          entry_credit: number
          entry_date: string
          entry_debit: number
          entry_id: number
          entry_number: string
          line_description: string
          line_id: number
          reference_id: number
          reference_type: string
        }[]
      }
      get_partner_ledger: {
        Args: { p_partner_id: number }
        Returns: {
          amount: number
          description: string
          reference_type: string
          running_balance: number
          signed_amount: number
          transaction_date: string
          transaction_id: number
          transaction_type: string
          treasury_id: number
        }[]
      }
      get_partner_profit_distribution_items: {
        Args: { p_distribution_id: number }
        Returns: {
          allocated_amount: number
          distribution_item_id: number
          paid_amount: number
          partner_id: number
          partner_name: string
          remaining_amount: number
          share_percentage: number
        }[]
      }
      get_period_summary: {
        Args: { p_from: string; p_to: string }
        Returns: Json
      }
      get_profit_loss: {
        Args: { p_from: string; p_to: string }
        Returns: {
          cogs: number
          expenses: number
          profit: number
          revenue: number
        }[]
      }
      get_sales_invoice_lot_allocations: {
        Args: { p_sales_invoice_id: number }
        Returns: {
          allocated_quantity: number
          expires_on: string
          lot_code: string
          lot_id: number
          package_option_id: number
          product_id: number
          sales_invoice_item_id: number
          unit_id: number
        }[]
      }
      get_sales_return_rework_stock: {
        Args: { p_location_id?: number }
        Returns: {
          available_quantity: number
          location_id: number
          product_id: number
          received_at: string
          return_item_id: number
          return_number: string
        }[]
      }
      get_sales_returns_for_current_user: {
        Args: { p_customer_id?: number; p_from?: string; p_to?: string }
        Returns: Json[]
      }
      get_slow_moving_stock: {
        Args: { p_days: number }
        Returns: {
          last_movement_date: string
          location_name: string
          product_id: number
          product_name: string
          quantity: number
        }[]
      }
      get_stock_by_location: {
        Args: { p_location_id?: number }
        Returns: {
          base_unit_id: number
          location_id: number
          location_name: string
          product_code: string
          product_id: number
          product_name: string
          quantity: number
        }[]
      }
      get_supplier_payable_balances: {
        Args: never
        Returns: {
          current_payable: number
          is_active: boolean
          supplier_id: number
          supplier_name: string
        }[]
      }
      get_total_cash: { Args: never; Returns: number }
      get_treasury_statement: {
        Args: { p_treasury_id: number }
        Returns: {
          deposit: number
          description: string
          running_balance: number
          transaction_date: string
          withdraw: number
        }[]
      }
      get_trial_balance: {
        Args: { p_from: string; p_to: string }
        Returns: {
          account_code: string
          account_name: string
          total_credit: number
          total_debit: number
        }[]
      }
      get_trip_returns: {
        Args: { p_trip_id: number }
        Returns: {
          cash_action: string
          customer_name: string
          price_difference: number
          return_date: string
          return_number: string
          sales_return_id: number
          status: string
          total_returned_value: number
          treasury_id: number
        }[]
      }
      get_trip_sales_rep_names: {
        Args: never
        Returns: {
          rep_name: string
          trip_id: number
        }[]
      }
      get_trip_stock_reconciliation: {
        Args: { p_trip_id: number }
        Returns: {
          base_unit_name: string
          calculated_remaining: number
          exchanged_quantity: number
          loaded_quantity: number
          previously_received_quantity: number
          product_code: string
          product_id: number
          product_name: string
          quantity_difference: number
          returned_quantity: number
          sold_quantity: number
          vehicle_quantity: number
        }[]
      }
      get_trip_summary: { Args: { p_trip_id: number }; Returns: Json }
      get_unassigned_rep_custody_summary: {
        Args: never
        Returns: {
          cash_amount: number
          personal_amount: number
          rep_name: string
          sales_rep_id: number
          total_amount: number
        }[]
      }
      get_vehicle_load_suggestions: {
        Args: { p_trip_count?: number; p_vehicle_id: number }
        Returns: {
          average_net_sold: number
          completed_trips: number
          product_code: string
          product_id: number
          product_name: string
          suggested_quantity: number
          total_net_sold: number
          unit_code: string
          unit_id: number
        }[]
      }
      has_permission: { Args: { p_permission_code: string }; Returns: boolean }
      inventory_count_approve: {
        Args: { p_notes?: string; p_session_id: number }
        Returns: number
      }
      inventory_count_create: {
        Args: { p_count_date?: string; p_notes?: string }
        Returns: number
      }
      inventory_count_get: { Args: { p_session_id: number }; Returns: Json }
      inventory_count_list: { Args: never; Returns: Json }
      inventory_count_save: {
        Args: { p_counts: Json; p_session_id: number }
        Returns: number
      }
      is_partner_user: { Args: never; Returns: boolean }
      load_trip_stock: {
        Args: {
          p_product_id: number
          p_quantity: number
          p_source_location_id: number
          p_trip_id: number
        }
        Returns: undefined
      }
      lookup_user_id_by_username: {
        Args: { p_username: string }
        Returns: string
      }
      mark_notification_read: {
        Args: { p_notification_id: string }
        Returns: undefined
      }
      pay_partner_profit_distribution_item: {
        Args: {
          p_amount: number
          p_distribution_item_id: number
          p_notes: string
          p_payment_date: string
          p_request_id: string
          p_treasury_id: number
        }
        Returns: number
      }
      post_customer_collection: {
        Args: {
          p_amount: number
          p_collection_date?: string
          p_collection_number: string
          p_created_by?: string
          p_notes?: string
          p_payment_method: string
          p_reference_number?: string
          p_sales_invoice_id: number
          p_sales_rep_id?: number
          p_trip_id?: number
        }
        Returns: number
      }
      post_fixed_asset_depreciation: {
        Args: {
          p_asset_id: number
          p_depreciation_month: string
          p_request_id: string
        }
        Returns: number
      }
      post_journal_entries: {
        Args: { p_from: string; p_to: string }
        Returns: Json
      }
      post_journal_entry: {
        Args: {
          p_description: string
          p_entry_date: string
          p_lines: Json
          p_reference_id: number
          p_reference_type: string
        }
        Returns: number
      }
      post_sales_return: {
        Args: { p_created_by?: string; p_sales_return_id: number }
        Returns: undefined
      }
      post_sales_return_exchange_v1: {
        Args: { p_created_by?: string; p_sales_return_id: number }
        Returns: undefined
      }
      post_sales_return_journal: {
        Args: { p_sales_return_id: number }
        Returns: undefined
      }
      record_current_user_login: { Args: never; Returns: boolean }
      record_sales_return_item_inspection: {
        Args: {
          p_disposition: string
          p_inspector_type: string
          p_notes?: string
          p_return_item_id: number
          p_rework_quantity?: number
          p_scrap_quantity?: number
          p_sellable_quantity?: number
        }
        Returns: Json
      }
      remove_production_order_extra_material: {
        Args: { p_material_id: number; p_order_id: number }
        Returns: undefined
      }
      request_trip_load_v2: {
        Args: {
          p_package_option_id?: number
          p_product_id: number
          p_quantity: number
          p_trip_id: number
        }
        Returns: number
      }
      reverse_journal_entries: {
        Args: {
          p_description: string
          p_reference_id: number
          p_reference_type: string
        }
        Returns: undefined
      }
      reverse_production_order: {
        Args: { p_order_id: number; p_reason?: string }
        Returns: Json
      }
      reverse_stock_transfer: {
        Args: {
          p_original_transfer_id: number
          p_reason: string
          p_request_id: string
        }
        Returns: number
      }
      set_partner_opening_balance: {
        Args: { p_new_balance: number; p_partner_id: number }
        Returns: number
      }
      set_partner_opening_balance_v2: {
        Args: {
          p_new_balance: number
          p_partner_id: number
          p_request_id: string
        }
        Returns: number
      }
      set_party_opening_balance: {
        Args: {
          p_new_balance: number
          p_party_id: number
          p_party_type: string
        }
        Returns: number
      }
      set_party_opening_balance_v2: {
        Args: {
          p_new_balance: number
          p_party_id: number
          p_party_type: string
          p_request_id: string
        }
        Returns: number
      }
      set_stock_balance: {
        Args: {
          p_location_id: number
          p_new_quantity: number
          p_notes?: string
          p_product_id: number
        }
        Returns: undefined
      }
      set_stock_opening_balance: {
        Args: {
          p_base_quantity: number
          p_location_id: number
          p_product_id: number
          p_unit_cost: number
        }
        Returns: number
      }
      set_treasury_opening_balance: {
        Args: { p_new_balance: number; p_treasury_id: number }
        Returns: number
      }
      settle_trip: {
        Args: { p_target_location_id: number; p_trip_id: number }
        Returns: undefined
      }
      settle_trip_internal_return_hold: {
        Args: { p_target_location_id: number; p_trip_id: number }
        Returns: undefined
      }
      settle_unassigned_rep_collections: {
        Args: {
          p_company_treasury_id: number
          p_request_id: string
          p_sales_rep_id: number
        }
        Returns: number
      }
      sync_trip_load_actual_quantities: {
        Args: { p_trip_id: number }
        Returns: undefined
      }
      transfer_treasury_funds: {
        Args: {
          p_amount: number
          p_destination_treasury_id: number
          p_notes?: string
          p_source_treasury_id: number
        }
        Returns: undefined
      }
      transfer_treasury_funds_v2: {
        Args: {
          p_amount: number
          p_destination_treasury_id: number
          p_notes: string
          p_request_id: string
          p_source_treasury_id: number
        }
        Returns: number
      }
      update_production_order_draft: {
        Args: {
          p_factory_location_id: number
          p_notes?: string
          p_order_id: number
          p_target_quantity: number
        }
        Returns: Json
      }
      update_sales_order_item: {
        Args: {
          p_discount_percent: number
          p_quantity: number
          p_sales_order_item_id: number
        }
        Returns: undefined
      }
      validate_sales_return: {
        Args: { p_sales_return_id: number }
        Returns: boolean
      }
      validate_sales_return_exchange_v1: {
        Args: { p_sales_return_id: number }
        Returns: boolean
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
