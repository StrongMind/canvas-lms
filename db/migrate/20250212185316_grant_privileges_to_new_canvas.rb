# frozen_string_literal: true

class GrantPrivilegesToNewCanvas < ActiveRecord::Migration[5.0]
  tag :predeploy

  def change
    reversible do |dir|
      dir.up do
        execute grants_sql
      end

      dir.down do
        # DO NOTHING
      end
    end
  end

  def grants_sql
    <<-SQL.squish
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1
          FROM pg_catalog.pg_roles
          WHERE rolname = 'new_canvas'
        ) THEN
          IF EXISTS (
            SELECT 1
            FROM pg_catalog.pg_roles
            WHERE rolname = 'rds_superuser'
          ) THEN
            GRANT rds_superuser TO new_canvas;
          END IF;
        END IF;
      END;
      $$;
     SQL
  end
end
