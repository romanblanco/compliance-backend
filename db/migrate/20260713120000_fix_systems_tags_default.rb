# frozen_string_literal: true

class FixSystemsTagsDefault < ActiveRecord::Migration[7.1]
  def up
    change_column_default :systems, :tags, from: {}, to: []
    execute "UPDATE systems SET tags = '[]'::jsonb WHERE tags = '{}'::jsonb"
  end

  def down
    change_column_default :systems, :tags, from: [], to: {}
  end
end
