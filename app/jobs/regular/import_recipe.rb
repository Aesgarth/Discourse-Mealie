# frozen_string_literal: true

module Jobs
  class ImportRecipe < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.mealie_integration_enabled
      
      recipe_id = args[:recipe_id]
      return if recipe_id.blank?
      
      client = MealieIntegration::MealieClient.new
      recipe = client.get_recipe(recipe_id)
      return if recipe.nil?
      
      # Check if we've already imported this recipe
      post = find_existing_post(recipe_id)
      
      if post
        # Update the existing post
        update_recipe_post(post, recipe)
      else
        # Create a new post
        create_recipe_post(recipe)
      end
    end
    
    private
    
    def find_existing_post(recipe_id)
      Post.find_by("raw LIKE ?", "%mealie-recipe-id: #{recipe_id}%")
    end
    
    def create_recipe_post(recipe)
      # Find or create the appropriate category
      category_id = SiteSetting.mealie_default_category_id
      
      # Create the post as system user
      creator = PostCreator.new(
        Discourse.system_user,
        title: recipe['name'],
        raw: format_recipe_post(recipe),
        category: category_id,
        skip_validations: true
      )
      
      post = creator.create
      
      # Optionally tag the post
      if post.present? && SiteSetting.mealie_tag.present?
        topic = post.topic
        tag_names = [SiteSetting.mealie_tag]
        DiscourseTagging.tag_topic_by_names(topic, Guardian.new(Discourse.system_user), tag_names)
      end
    end
    
    def update_recipe_post(post, recipe)
      post.raw = format_recipe_post(recipe)
      post.save(validate: false)
      post.rebake!
    end
    
    def format_recipe_post(recipe)
      # Format the recipe data into a Discourse post
      raw = <<~RAW
        <!-- mealie-recipe-id: #{recipe['id']} -->
        
        # #{recipe['name']}
        
        ![Recipe Image](#{recipe['image_url']}) 
        
        #{recipe['description']}
        
        ## Ingredients
        
        #{format_ingredients(recipe['recipe_ingredient'])}
        
        ## Instructions
        
        #{format_instructions(recipe['recipe_instruction'])}
        
        ## Details
        
        * Prep Time: #{recipe['prep_time']} minutes
        * Cook Time: #{recipe['cook_time']} minutes
        * Servings: #{recipe['recipe_yield']}
        
        [View in Mealie](#{SiteSetting.mealie_url}/recipe/#{recipe['id']})
      RAW
      
      raw
    end
    
    def format_ingredients(ingredients)
      return "No ingredients listed" if ingredients.nil? || ingredients.empty?
      ingredients.map { |ingredient| "* #{ingredient['note'] || ''} #{ingredient['food']} #{ingredient['unit'] || ''}" }.join("\n")
    end
    
    def format_instructions(instructions)
      return "No instructions listed" if instructions.nil? || instructions.empty?
      instructions.map.with_index { |instruction, index| "#{index + 1}. #{instruction['text']}" }.join("\n")
    end
  end
end