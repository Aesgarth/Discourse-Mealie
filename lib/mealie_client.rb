# lib/mealie_client.rb
module MealieIntegration
  class MealieClient
    def initialize
      @api_url = SiteSetting.mealie_url.chomp('/') + '/api'
      @api_key = SiteSetting.mealie_api_key
    end
    
    def get_recipe(recipe_id)
      response = get("/recipes/#{recipe_id}")
      return nil unless response.success?
      
      JSON.parse(response.body)
    end
    
    def list_recipes(page = 1, per_page = 10)
      response = get("/recipes?page=#{page}&per_page=#{per_page}")
      return [] unless response.success?
      
      JSON.parse(response.body)
    end
    
    private
    
    def get(endpoint)
      Excon.get(
        "#{@api_url}#{endpoint}",
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@api_key}"
        }
      )
    end
  end
end