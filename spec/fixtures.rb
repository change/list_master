#
# Create db and table
#

TEST_DB ||= 'tmp/testdb.sqlite3'
FileUtils.rm_f TEST_DB

SQLite3::Database.new(TEST_DB) do |db| db.execute_batch <<-SQL
    CREATE TABLE items (
    id INTEGER PRIMARY KEY,
    name TEXT,
    category TEXT,
    created_at DATE,
    updated_at DATE
  );

  CREATE TABLE assoc_items (
    id INTEGER PRIMARY KEY,
    item_id INTEGER,
    rank INTEGER,
    kind TEXT
  );

  CREATE TABLE items_multi_items (
    item_id INTEGER,
    multi_item_id INTEGER
  );

  CREATE TABLE multi_items (
    id INTEGER PRIMARY KEY,
    name TEXT
  );

  SQL
end

#
# An example model
#

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: TEST_DB

class Item < ActiveRecord::Base
  has_many :assoc_items
  has_and_belongs_to_many :multi_items

  scope :has_category, where('category IS NOT NULL')
end

class AssocItem < ActiveRecord::Base
  belongs_to :item
end

class MultiItem < ActiveRecord::Base
  has_and_belongs_to_many :items
end
