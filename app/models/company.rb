class Company < ApplicationRecord
  has_and_belongs_to_many :statements,
                          -> { order(last_year_covered: :desc, date_seen: :desc) }
  belongs_to :country, optional: true
  belongs_to :industry, optional: true

  validates :name, presence: true, uniqueness: true

  accepts_nested_attributes_for :statements, reject_if: :all_blank, allow_destroy: true

  before_destroy :delete_orphaned_statements

  def latest_statement
    statements.limit(1).first
  end

  def latest_published_statement
    published_statements.first
  end

  def published_statements
    statements.published
  end

  def country_name
    try(:country).try(:name) || 'Country unknown'
  end

  def industry_name
    try(:industry).try(:name) || 'Industry unknown'
  end

  def self.search(query)
    wild = "%#{query}%"
    Company.where(
      'lower(name) like lower(?)',
      wild
    )
  end

  def associate_all_statements_with_user(user)
    statements.each { |s| s.associate_with_user user }
  end

  def remove_blank_first_statement
    self.statements = [] if statements.first.present? && statements.first.url.blank?
  end

  def to_param
    [id, name.parameterize].join('-')
  end

  private

  def delete_orphaned_statements
    statements.each do |statement|
      statement.destroy if statement.companies == [self]
    end
  end
end
