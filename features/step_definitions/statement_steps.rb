Given(/^the following statements have been submitted:$/) do |table|
  table.hashes.each do |props|
    company = Company.find_or_create_by(name: props['company_name'])
    company.statements.create!({url: props['statement_url']})
  end
end

When(/^([A-Z]\w+) submits the following statement for "([^"]*)":$/) do |actor, company_name, table|
  props = table.rows_hash
  actor.attempts_to(
    SubmitStatement
      .for_existing_company(company_name)
      .with_statement_url(props['url'])
      .signed_by_director(props['signed_by_director'].match(/yes/i))
      .approved_by_board(props['approved_by_board'].match(/yes/i))
      .link_on_front_page(props['link_on_front_page'].match(/yes/i))
  )
end

When(/^([A-Z]\w+) submits the following statement:$/) do |actor, table|
  props = table.rows_hash
  actor.attempts_to(
    SubmitStatement
      .for_new_company(props['company_name'])
      .with_statement_url(props['url'])
      .signed_by_director(props['signed_by_director'].match(/yes/i))
      .approved_by_board(props['approved_by_board'].match(/yes/i))
      .link_on_front_page(props['link_on_front_page'].match(/yes/i))
  )
end

Then(/^([A-Z]\w+) should see (\d+) statements? for "([^"]*)"$/) do |actor, statement_count, company_name|
  expect(actor.to_see(Statements.for(company_name)).length()).to eq(statement_count.to_i)
end

Then(/^([A-Z]\w+) should see (\d+) statements total$/) do |actor, statement_count|
  expect(actor.to_see(Statements.for_all_companies).length()).to eq(statement_count.to_i)
end

class SubmitStatement < Fellini::Task
  include Rails.application.routes.url_helpers

  def perform_as(actor)
    browser = Fellini::Abilities::BrowseTheWeb.as(actor)

    if(@new_company)
      browser.visit(new_company_statement_companies_path)
      browser.fill_in('Company Name', with: @company_name)
    else
      company = Company.find_by_name(@company_name)
      browser.visit(new_company_statement_path(company))
    end
    browser.fill_in('Statement URL', with: @url)
    browser.check('Signed by director') if @signed_by_director
    browser.check('Approved by board') if @approved_by_board
    browser.check('Link on front page') if @link_on_front_page
    browser.click_button 'Submit'
  end

  def self.for_new_company(company_name)
    instrumented(self, company_name, true)
  end

  def self.for_existing_company(company_name)
    instrumented(self, company_name, false)
  end

  def initialize(company_name, new_company)
    @company_name = company_name
    @new_company = new_company
  end

  def with_statement_url(url)
    @url = url
    self
  end

  def signed_by_director(bool)
    @signed_by_director = bool
    self
  end

  def approved_by_board(bool)
    @approved_by_board = bool
    self
  end

  def link_on_front_page(bool)
    @link_on_front_page = bool
    self
  end
end

class Statements < Fellini::Question
  include Rails.application.routes.url_helpers

  def answered_by(actor)
    browser = Fellini::Abilities::BrowseTheWeb.as(actor)
    browser.visit(@page_url)
    browser.all('[data-content="statement"]').map do |statement_element|
      # TODO: Return an actual statement. For now we're just counting,
      # so not necessary
      "X"
    end
  end

  def initialize(company)
    @page_url = company ? company_path(company) : root_path
  end

  def self.for(company_name)
    new(Company.find_by_name!(company_name))
  end

  def self.for_all_companies()
    new(nil)
  end
end
