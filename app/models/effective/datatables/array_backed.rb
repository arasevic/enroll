
module Effective
  module Datatables
    class ArrayBacked < Effective::MongoidDatatable
      datatable do


        bulk_actions_column do
           bulk_action 'Generate Invoice', generate_invoice_exchanges_hbx_profiles_path, data: { method: :post, confirm: 'Generate Invoices?' }
           bulk_action 'Mark Binder Paid', generate_invoice_exchanges_hbx_profiles_path, data: { method: :post, confirm: 'Mark Binder Paid?' }
        end

        table_column :legal_name, :proc => Proc.new { |row| link_to row.legal_name.titleize, employers_employer_profile_path(row.employer_profile, :tab=>'home')}, :sortable => false, :filter => false
        table_column :hbx_id, :width => '100px', :proc => Proc.new { |row| truncate(row.id.to_s, length: 8, omission: '' ) }, :sortable => false, :filter => false
        table_column :fein, :width => '100px', :proc => Proc.new { |row| row.fein }, :sortable => false, :filter => false
        table_column :plan_year_status, :width => '120px', :proc => Proc.new { |row| row.employer_profile.renewing_plan_year.present? ? 'Renewing' : 'New'}, :filter => false
        # table_column :eligibility, :proc => Proc.new { |row| eligibility_criteria(row.employer_profile) }, :filter => false
        table_column :broker, :proc => Proc.new { |row|
            row.employer_profile.broker_agency_profile.organization.legal_name.titleize if row.employer_profile.broker_agency_profile.present?
          }, :filter => false
        table_column :general_agency, :proc => Proc.new { |row|
          row.employer_profile.active_general_agency_legal_name.titleize if row.employer_profile.active_general_agency_legal_name.present?
        }, :filter => false
        table_column :conversion, :width => '120px', :proc => Proc.new { |row| boolean_to_glyph(row.employer_profile.is_conversion?)}, :filter => {include_blank: false, :as => :select, :collection => ['All','Yes', 'No'], :selected => 'All'}
        #table_column :state,:proc => Proc.new { |row| row.primary_office_location.try(:address).try(:state)} , :filter => false
        table_column :plan_year_state, :proc => Proc.new { |row| row.employer_profile.try(:latest_plan_year).try(:aasm_state).try(:titleize)}, :filter => false
        table_column :invoiced, :proc => Proc.new { |row| boolean_to_glyph(row.current_month_invoice.present?)}, :filter => false
        #table_column :update_at, :proc => Proc.new { |row| row[5].strftime('%m/%d/%Y')}

      end


      def collection
        employers = Organization.all_employer_profiles

        if attributes[:enrollment].present? && !['all','date_window','date_cat'].include?(attributes[:enrollment])
          employers = employers.send(attributes[:enrollment])
        end

        employers

      end

      def global_search?
        true
      end

      def search_column(collection, table_column, search_term, sql_column)
        if table_column[:name] == 'legal_name'
          collection.datatable_search(search_term)
        elsif table_column[:name] == 'fein'
          collection.datatable_search_fein(search_term)
        elsif table_column[:name] == 'conversion'
          if search_term == "Yes"
            collection.datatable_search_employer_profile_source("conversion")
          elsif search_term == "No"
            collection.datatable_search_employer_profile_source("self_serve")
          else
            super
          end
        else
          super
        end
      end

      def nested_filter_definition

        @next_30_day = TimeKeeper.date_of_record.next_month.beginning_of_month
        @next_60_day = @next_30_day.next_month
        @next_90_day = @next_60_day.next_month

        filters = {
        #   ivl_category:
        #   [
        #    ['all', 'All', ],
        #    ['assisted', 'Assisted', ],
        #    ['unassisted', 'Unassisted', ],
        #    ['cover_all', 'Cover All', ],
        #    ['sep_eligible', 'SEP Eligible', ],
        #   ],
        # ivl_state:
        #   [
        #     ['all', 'All', :ivl_category ],
        #     ['enrolled', 'Enrolled', :ivl_category],
        #     ['renewing', 'Renewing', :ivl_category],
        #     ['waived', 'Waived', :ivl_category],
        #   ],
        # ee_category:
        #   [
        #     ['all', 'All', :ivl_category ],
        #     ['active', 'Active', ],
        #     ['renewing', 'Renewing'],
        #     ['cobra', 'Cobra'],
        #     ['terminated', 'Terminated'],
        #   ],
        # ee_state:
        #   [
        #     ['enrolled', 'Enrolled', :ee_category],
        #     ['renewing', 'Renewing', :ee_category],
        #     ['waived', 'Waived'],
        #     ['terminated', 'Terminated'],
        #     ['sep_eligible', 'SEP Eligible', :ee_category],
        #   ],
        date_window:
          [
            [@next_30_day,@next_30_day],
            [@next_60_day,@next_60_day],
            [@next_90_day,@next_90_day],
          ],
        enrollment:
         [
           ['all', 'All'],
           ['all_employers_enrolled', 'Enrolled'],
           ['employer_profile_initial_coverage', 'Enrolling'],
           ['all_employers_renewing', 'Renewing'],
           ['date_cat', 'Upcoming Dates', :date_window]  #maybe no sub menu?
         ],
        top_scope: :enrollment
        }

      end
    end
  end
end
