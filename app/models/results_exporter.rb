require 'csv'

class ResultsExporter
  # rubocop:disable Metrics/MethodLength
  def self.to_csv(results, admin, params = {})
    fields = BASIC_FIELDS.merge(admin ? EXTRA_FIELDS : {})
    legislation_ids = params[:legislations] && params[:legislations].map(&:to_i)

    CSV.generate do |csv|
      csv << fields.map { |_, heading| heading }

      results.includes(statements: [:additional_companies_covered_ordered_by_name, :legislations]).find_each do |company|
        company.statements.each do |statement|
          next unless statement.published || admin

          if legislation_ids.present? && statement.legislation_ids.exclude?(*legislation_ids)
            next
          end

          csv << StatementExport.export(statement, fields)
          # Change the company context when there are additional_companies
          statement.additional_companies_covered_excluding(company).each do |ac|
            csv << StatementExport.export(statement, fields, context: ac)
          end
        end
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

  BASIC_FIELDS = {
    company_id: 'Company ID',
    company_name: 'Company',
    published_by?: 'Is Publisher',
    id: 'Statement ID',
    url: 'URL',
    override_url: 'Override URL',
    company_number: 'Companies House Number',
    industry_name: 'Industry',
    country_name: 'HQ',
    also_covered_and_published_by?: 'Is Also Covered',
    'uk_modern_slavery_act?' => Legislation::UK_NAME,
    'california_transparency_in_supply_chains_act?' => Legislation::CALIFORNIA_NAME,
    'aus_modern_slavery_act?' => Legislation::AUS_NAME,
    period_covered: 'Period Covered'
  }.freeze

  EXTRA_FIELDS = {
    approved_by_board: 'Approved by Board',
    approved_by: 'Approved by',
    signed_by_director: 'Signed by Director',
    signed_by: 'Signed by',
    link_on_front_page: 'Link on Front Page',
    published: 'Published',
    verified_by_email: 'Verified by',
    contributor_email: 'Contributed by',
    broken_url: 'Broken URL',
    home_office_audit: 'Home Office Audit'
  }.freeze
end
