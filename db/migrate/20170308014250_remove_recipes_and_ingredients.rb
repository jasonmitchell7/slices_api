class RemoveRecipesAndIngredients < ActiveRecord::Migration[5.0]
  def change
    rename_column :settings, :notify_on_recipe_activity, :notify_on_unpublished_activity

    drop_table :recipes
    drop_table :ingredients
  end
end
