# app/jobs/scheduled/sync_mealie_recipes.rb
module Jobs
  class SyncMealieRecipes < ::Jobs::Scheduled
    every 1.hour
    
    def execute(args)
      return unless SiteSetting.mealie_integration_enabled
      
      # Use the enum value instead of symbol
      sync_frequency = SiteSetting.mealie_sync_frequency
      return if sync_frequency == MealieIntegration::SYNC_FREQUENCIES[:never]
      
      # Hourly synchronization
      if sync_frequency == MealieIntegration::SYNC_FREQUENCIES[:hourly]
        sync_recipes
      # Daily synchronization - only run once per day
      elsif sync_frequency == MealieIntegration::SYNC_FREQUENCIES[:daily] && Time.now.hour == 0
        sync_recipes
      end
    end
    
    def sync_recipes
      client = MealieIntegration::MealieClient.new
      last_sync = SiteSetting.mealie_last_sync || 10.years.ago.iso8601
      
      # Get recipes that were added since last sync
      new_recipes = client.list_recipes_since(last_sync)
      
      new_recipes.each do |recipe|
        Jobs.enqueue(:import_recipe, recipe_id: recipe['id'])
      end
      
      # Update last sync time
      SiteSetting.mealie_last_sync = Time.now.iso8601
    end
  end
end