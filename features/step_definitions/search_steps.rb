When('{actor} searches for {string}') do |actor, query|
  actor.attempts_to_search_for(query)
end

When('{actor} selects industry {string}') do |actor, industry|
  actor.attempts_to_filter_by_industry(industry)
end

When('{actor} selects legislation {string}') do |actor, legislation|
  legislations = legislation.split(',').map(&:strip)
  actor.attempts_to_filter_by_legislation(legislations)
end

Then('{actor} should find no company called {string} exists') do |actor, company_name|
  actor.attempts_to_search_for(company_name)
  expect(actor.visible_statement_search_results_summary).to eq('No statements found')
end

Given('a search alias from {string} to {string} exists') do |target, substitution|
  query = "INSERT INTO search_aliases VALUES(DEFAULT, to_tsquery('#{target}'), to_tsquery('#{substitution}'));"
  ActiveRecord::Base.connection.execute(query)
end

module ExploresStatements
  def attempts_to_search_for(query)
    visit explore_path
    fill_in 'company_name', with: query
    click_button 'Search'
  end

  def attempts_to_search_in_admin_for(query)
    visit admin_companies_path
    fill_in 'query', with: query
    click_button 'Search'
  end

  def attempts_to_filter_by_industry(industry)
    visit explore_path
    select industry, from: 'industries_'
    click_button 'Search'
  end

  def attempts_to_filter_by_legislation(legislations)
    visit explore_path
    legislations.each do |legislation|
      select legislation, from: 'legislations_'
    end
    click_button 'Search'
  end

  def visible_statement_search_results_summary
    find('[data-content="company_search_results"] h2').text
  end
end

class Visitor
  include ExploresStatements
end
