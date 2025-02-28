# name: Discourse-Mealie
# about: Integrates Mealie recipe manager with Discourse forums
# version: 0.1
# authors: Aesgarth
# url: https://github.com/Aesgarth/Discourse-Mealie
# required_version: 2.7.0

enabled_site_setting :mealie_integration_enabled

# Define the module and constants outside after_initialize
module ::MealieIntegration
  SYNC_FREQUENCIES = {
    never: 0,
    hourly: 1,
    daily: 2
  }
end

register_asset 'stylesheets/mealie-integration.scss'

after_initialize do
  # Load our dependencies
  load File.expand_path('../lib/mealie_client.rb', __FILE__)
  load File.expand_path('../app/controllers/mealie_controller.rb', __FILE__)
  load File.expand_path('../app/jobs/scheduled/sync_mealie_recipes.rb', __FILE__)
  load File.expand_path('../app/jobs/regular/import_recipe.rb', __FILE__)
  
  # Add our API endpoints
  Discourse::Application.routes.append do
    mount ::MealieIntegration::Engine, at: "/mealie"
  end
  
  module ::MealieIntegration
    class Engine < ::Rails::Engine
      engine_name "mealie_integration"
      isolate_namespace MealieIntegration
      
      routes do
        get "/" => "mealie#index"
        post "/webhook" => "mealie#webhook"
        post "/import" => "mealie#import"
      end
    end
  end
end