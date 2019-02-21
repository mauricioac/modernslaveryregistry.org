require 'csv'

class StatementExport
  def self.to_csv(companies, admin)
    fields = BASIC_FIELDS.merge(admin ? EXTRA_FIELDS : {})
    CSV.generate do |csv|
      csv << fields.map { |_, heading| heading }
      companies.each do |company|
        company.statements.each do |statement|
          csv << fields.map { |name, _| format_for_csv(statement.send(name)) }
        end
      end
    end
  end

  def self.format_for_csv(value)
    value.respond_to?(:iso8601) ? value.iso8601 : value
  end

  BASIC_FIELDS = {
    company_name: 'Company',
    url: 'URL',
    industry_name: 'Industry',
    country_name: 'HQ',
    also_covers_companies: 'Also Covers Companies',
    'uk_modern_slavery_act?' => Legislation::UK_NAME,
    'california_transparency_in_supply_chains_act?' => Legislation::CALIFORNIA_NAME,
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
    company_id: 'Company ID'
  }.freeze
end
