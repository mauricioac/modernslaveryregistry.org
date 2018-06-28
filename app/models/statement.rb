require 'uri'

class Statement < ApplicationRecord # rubocop:disable Metrics/ClassLength
  # Why optional: true
  # https://stackoverflow.com/questions/35942464/trouble-with-accepts-nested-attributes-for-in-rails-5-0-0-beta3-api-option/36254714#36254714
  belongs_to :company, optional: true
  belongs_to :verified_by, class_name: 'User', optional: true
  has_one :snapshot, dependent: :destroy
  has_many :legislation_statements, dependent: :destroy
  has_many :legislations, through: :legislation_statements

  validates :url, presence: true, url_format: true
  validates :link_on_front_page, boolean: true, if: -> { legislation_requires?(:link_on_front_page) }
  validates :approved_by_board, yes_no_not_explicit: true, if: -> { legislation_requires?(:approved_by_board) }
  validates :signed_by_director, boolean: true, if: -> { legislation_requires?(:signed_by_director) }

  before_create { self.date_seen ||= Time.zone.today }
  after_save :enqueue_snapshot unless ENV['no_fetch']
  after_commit :perform_snapshot_job
  after_save :mark_latest
  after_save :mark_latest_published

  scope(:published, -> { where(published: true) })
  scope(:latest, -> { where(latest: true) })
  scope(:latest_published, -> { where(latest_published: true) })

  delegate :country_name, :industry_name, to: :company

  attr_accessor :should_enqueue_snapshot

  def self.search(include_unpublished:, criteria:)
    StatementSearch.new(include_unpublished, criteria)
  end

  def self.url_exists?(url)
    uri = URI(url)
    uri.scheme = 'https'
    return true if exists?(url: uri.to_s)
    uri.scheme = 'http'
    exists?(url: uri.to_s)
  end

  def self.bulk_create!(company_name, statement_url, legislation_name)
    return if Statement.url_exists?(statement_url)

    begin
      company = Company.find_or_create_by!(name: company_name)
      legislation = Legislation.find_by(name: legislation_name)
      statement = company.statements.create!(url: statement_url)
      statement.legislations << legislation
    rescue ActiveRecord::RecordInvalid => e
      e.message += "\nCompany Name: '#{company_name}', Statement URL: '#{statement_url}'"
      raise e
    end
  end

  def associate_with_user(user)
    self.verified_by ||= user if user.admin? && published?
    self.contributor_email = user && user.email if contributor_email.blank?
  end

  def fully_compliant?
    approved_by_board == 'Yes' && link_on_front_page? && signed_by_director?
  end

  def verified_by_email
    try(:verified_by).try(:email)
  end

  def contributor_or_verifier_email
    contributor_email.presence || verified_by_email
  end

  def self.to_csv(statements, extra)
    StatementExport.to_csv(statements, extra)
  end

  def enqueue_snapshot
    @should_enqueue_snapshot = true if saved_change_to_url? || saved_change_to_marked_not_broken_url?
  end

  def perform_snapshot_job
    return unless @should_enqueue_snapshot
    FetchStatementSnapshotJob.perform_later(id)
    @should_enqueue_snapshot = false
  end

  def fetch_snapshot
    fetch_result = StatementUrl.fetch(url)
    self.url = fetch_result.url
    self.broken_url = fetch_result.broken_url

    return if broken_url

    build_snapshot_from_result(fetch_result)
  end

  def previewable_snapshot?
    snapshot.present? && snapshot.previewable?
  end

  def year_covered=(array_of_years)
    self.first_year_covered = array_of_years.map(&:to_i).min
    self.last_year_covered = array_of_years.map(&:to_i).max
  end

  def period_covered
    [first_year_covered, last_year_covered].uniq.join('-')
  end

  def period_covered=(period)
    years = period.split('-').map(&:to_i)
    self.first_year_covered = years[0]
    self.last_year_covered = years[1]
  end

  private

  def legislation_requires?(attribute)
    published? && legislations.any? { |legislation| legislation.requires_statement_attribute?(attribute) }
  end

  def company_name
    company.name
  end

  def build_snapshot_from_result(fetch_result)
    build_snapshot
    snapshot.original.attach(
      io: StringIO.new(fetch_result.content_data),
      filename: 'original',
      content_type: fetch_result.content_type
    )
    attach_screenshot_to_snapshot(snapshot)
  end

  def attach_screenshot_to_snapshot(snapshot)
    return unless snapshot.original_is_html?

    image_fetch_result = ScreenGrab.fetch(url)
    return if image_fetch_result.broken_url

    snapshot.screenshot.attach(
      io: StringIO.new(image_fetch_result.content_data),
      filename: 'screenshot.png',
      content_type: image_fetch_result.content_type
    )
  end

  # rubocop:disable Rails/SkipsModelValidations
  def mark_latest
    company.statements.update_all(latest: false)
    company.statements.limit(1).update_all(latest: true)
  end

  def mark_latest_published
    return unless published?
    company.statements.update_all(latest_published: false)
    company.statements.published.limit(1).update_all(latest_published: true)
  end
  # rubocop:enable Rails/SkipsModelValidations
end
