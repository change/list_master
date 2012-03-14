#
# Create db and table
#

TEST_DB = 'tmp/testdb.sqlite3'
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
    rank INTEGER
  );
  SQL
end

#
# An example model
#

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: TEST_DB

class Item < ActiveRecord::Base
  has_one :assoc_item
end

class AssocItem < ActiveRecord::Base
  belongs_to :item
end

Item.create! name: 'foo', category: 'a', :created_at => 2.months.ago      # id: 1
Item.create! name: 'bar', category: 'b', :created_at => 1.days.ago      # id: 2
Item.create! name: 'baz', category: 'b', :created_at => 30.seconds.ago  # id: 3

AssocItem.create! :item_id => 3, :rank => 1
AssocItem.create! :item_id => 1, :rank => 2
