require 'arproxy'
require 'active_record'
require 'dotenv/load'

Arproxy.logger.level = Logger::WARN unless ENV['DEBUG']

def ar_version
  "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
end

def cleanup_activerecord
  ActiveRecord::Base.connection.close
  ActiveRecord::Base.connection.clear_cache!
  ActiveRecord::Base.descendants.each(&:reset_column_information)
  ActiveRecord::Base.connection.schema_cache.clear!
end

RSpec::Matchers.define :add_query_log do |log_line_regex|
  supports_block_expectations

  match do |block|
    idx = QueryLogger.log.size
    block.call
    QueryLogger.log.size > idx && QueryLogger.log[idx..-1].any? { |log| log.match(log_line_regex) }
  end

  failure_message do |block|
    "expected to add query log matching #{log_line_regex.inspect}, but got #{QueryLogger.log.inspect}"
  end

  failure_message_when_negated do |block|
    "expected not to add query log matching #{log_line_regex.inspect}, but added"
  end

  def supports_block_expectations?
    true
  end
end

RSpec.shared_examples 'Arproxy does not break the original ActiveRecord functionality' do
  before do
    # CREATE
    ActiveRecord::Base.connection.create_table :products, force: true do |t|
      t.string :name
      t.integer :price
    end
    # INSERT
    Product.create(name: 'apple', price: 100)
    Product.create(name: 'banana', price: 200)
    Product.create(name: 'orange', price: 300)
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :products
  end

  context 'SELECT' do
    # it { expect(Product.where(name: ['apple', 'orange']).sum(:price)).to eq(400) }
    it { expect(Product.count).to eq(3) }
  end

  context 'UPDATE' do
    it do
      expect {
        Product.where(name: 'banana').update_all(price: 1000)
      }.to change {
        Product.find_by(name: 'banana').price
      }.from(200).to(1000)
    end
  end

  context 'DELETE' do
    it do
      expect {
        Product.where(name: 'banana').delete_all
      }.to change {
        Product.where(name: 'banana').exists?
      }.from(true).to(false)
    end
  end
end

RSpec.shared_examples 'Custom proxies work expectedly' do
  before do
    ActiveRecord::Base.connection.create_table :products, force: true do |t|
      t.string :name
      t.integer :price
    end
    Product.create(name: 'apple', price: 100)
    Product.create(name: 'banana', price: 200)
    Product.create(name: 'orange', price: 300)
    QueryLogger.reset!
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :products
  end

  around do |example|
    ActiveRecord::Base.uncached do
      example.run
    end
  end

  context 'CREATE TABLE' do
    it do
      expect {
        ActiveRecord::Base.connection.create_table :products, force: true do |t|
          t.string :name
          t.integer :price
        end
      }.to add_query_log(/^CREATE TABLE.*products.*$/)
    end
  end

  context 'SELECT' do
    it do
      expect {
        Product.where(name: ['apple', 'orange']).sum(:price)
      }.to add_query_log(/^SELECT.*products.*$/)
    end
  end

  context 'INSERT' do
    it do
      expect {
        Product.create(name: 'grape', price: 400)
      }.to add_query_log(/^INSERT INTO.*products.*$/)
    end
  end

  context 'UPDATE' do
    it do
      expect {
        Product.where(name: 'banana').update_all(price: 1000)
      }.to add_query_log(/^UPDATE.*products.*$/)
    end
  end

  context 'DELETE' do
    it do
      expect {
        Product.where(name: 'banana').delete_all
      }.to add_query_log(/^DELETE.*products.*$/)
    end
  end
end

class Product < ActiveRecord::Base
end

class QueryLogger < Arproxy::Base
  def execute(sql, name = nil)
    @@log ||= []
    @@log << sql
    if ENV['DEBUG']
      puts "QueryLogger: [#{name}] #{sql}"
    end
    super
  end

  def self.log
    @@log
  end

  def self.reset!
    @@log = []
  end
end

class HelloProxy < Arproxy::Base
  def execute(sql, name = nil)
    super("#{sql} -- Hello Arproxy!", name)
  end
end
