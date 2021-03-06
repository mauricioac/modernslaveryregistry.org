require 'csv'

module Admin
  class BulkUploadsController < AdminController
    def create
      csv_io = params[:csv]
      return alert_csv if csv_io.nil?

      # Admins frequently upload badly encoded CSVs, so just force fix it.
      csv = csv_io.read.encode(Encoding.find('UTF-8'), invalid: :replace, undef: :replace, replace: '')

      statement_params_array = CSV.parse(csv, headers: :first_row).map(&:to_hash)
      bulk_create(statement_params_array)
      flash[:notice] = 'Successfully imported statements'

      redirect_to admin_dashboard_path
    end

    def alert_csv
      flash[:alert] = 'Please select a CSV file'
      redirect_to admin_dashboard_path
    end

    def bulk_create(statement_params_array)
      statement_params_array.each do |params|
        begin
          Statement.bulk_create!(params['company_name'], params['statement_url'], params['legislation'])
        rescue StandardError => e
          logger.error(e)
        end
      end
    end
  end
end
