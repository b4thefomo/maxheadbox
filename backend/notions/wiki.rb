# heavily vibe-coded because I needed something fast that worked!

get '/wiki/:query' do
  query = params[:query]
  if query.nil? || query.strip.empty?
    status 400
    return { error: 'Query parameter is required.' }.to_json
  end

  begin
    summary_result = get_first_summary(query)
    if summary_result[:error]
      status 404
      summary_result.to_json
    else
      summary_result.to_json
    end
  rescue StandardError => e
    status 500
    { error: "An error occurred while fetching the summary: #{e.message}" }.to_json
  end
end

def get_first_summary(query)
  @logger.info "Searching Wikipedia for: #{query}"
  # Step 1: Search for the query to get a list of page IDs
  # We might get disambiguation pages here, so we'll need to filter.
  search_url = "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=#{URI.encode_www_form_component(query)}&format=json&srlimit=10" # Fetch up to 10 results
  search_response = RestClient.get(search_url)
  search_data = JSON.parse(search_response.body)

  if search_data['query'] && search_data['query']['search'].any?
    search_data['query']['search'].each do |result|
      page_id = result['pageid']
      @logger.info "Checking Wikipedia page ID: #{page_id} (Title: #{result['title']}) for query: #{query}"

      # Step 2: Get the extract and pageprops for the found page ID
      # We ask for 'pageprops' to check for disambiguation status.
      extract_url = "https://en.wikipedia.org/w/api.php?action=query&prop=extracts|pageprops&exintro&explaintext&pageids=#{page_id}&format=json"
      extract_response = RestClient.get(extract_url)
      extract_data = JSON.parse(extract_response.body)

      if extract_data['query'] && extract_data['query']['pages'] && extract_data['query']['pages'][page_id.to_s]
        page_data = extract_data['query']['pages'][page_id.to_s]

        if page_data['pageprops'] && page_data['pageprops']['disambiguation']
          @logger.info "Page ID #{page_id} is a disambiguation page. Skipping."
          next
        end

        if page_data['extract'] && !page_data['extract'].strip.empty?
          @logger.info "Successfully retrieved extract for non-disambiguation page ID: #{page_id}"
          return { summary: page_data['extract'] }
        else
          @logger.info "No extract found for non-disambiguation page ID: #{page_id}. Skipping."
          next
        end
      else
        @logger.warn "Could not retrieve detailed page data for ID: #{page_id}. Skipping."
        next
      end
    end

    @logger.info "No suitable non-disambiguation Wikipedia results found after checking multiple for: #{query}"
    { error: "No suitable Wikipedia results found for '#{query}'." }
  else
    @logger.info "No Wikipedia search results found for: #{query}"
    { error: "No Wikipedia results found for '#{query}'." }
  end
rescue RestClient::ExceptionWithResponse => e
  @logger.error "Wikipedia API error: #{e.response.body}"
  { error: "Wikipedia API error: #{e.response.body}" }
rescue JSON::ParserError => e
  @logger.error "Failed to parse Wikipedia API response: #{e.message}"
  { error: "Failed to parse Wikipedia API response: #{e.message}" }
rescue StandardError => e
  @logger.error "An unexpected error occurred in get_first_summary: #{e.message}"
  { error: "An unexpected error occurred: #{e.message}" }
end
