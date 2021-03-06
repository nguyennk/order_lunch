require 'open-uri'
require 'csv'
class Dish < ActiveRecord::Base
  attr_reader :image_logo_remote_url
  validates :name, presence: true, uniqueness: { scope: :restaurant, message: 'each restaurant doesn\'t have two dishes which are same named' }

  validates_numericality_of :price

  validates_presence_of :restaurant

  belongs_to :restaurant

  has_many :dish_orders
  has_many :orders, through: :dish_orders
  has_many :sized_prices

  belongs_to :parent, class_name: 'Dish'
  has_many :variants, class_name: 'Dish', foreign_key: 'parent_id'

  has_many :dish_component_associations
  has_many :dished_components, through: :dish_component_associations

  has_and_belongs_to_many :tags

  has_many :daily_restaurants, through: :provider_dish_mappings
  has_many :provider_dish_mappings

  has_attached_file :image_logo, styles: {
      thumb: '100x100>',
      square: '200x200#',
      medium: '300x300>'
  }

  # Validate the attached image is image/jpg, image/png, etc
  validates_attachment_content_type :image_logo, :content_type => /\Aimage\/.*\Z/

  def image_logo_remote_url=(url_value)
    self.image_logo = URI.parse(url_value)
    @image_logo_remote_url = url_value
  end

  def display_name
    name.split(/\[[^\[]*\]/).last
  end

  def self.import(file)
    result = { success: [], fail: [] }
    CSV.foreach(file.path, headers: true) do |row|
      attrs = row.to_hash
      attrs["name"] = "#{attrs["name"]} [#{attrs["size"]}]" unless attrs["size"].blank?
      tag_name = attrs.delete 'tags'
      img_url = attrs.delete 'image_url'
      parent = attrs.delete 'parent'

      begin
        adish = Dish.create attrs

        unless tag_name.blank?
          tag = Tag.find_by(name: tag_name) || Tag.create(name: tag_name)
          adish.tags = [tag]
        end

        unless img_url.blank?
          adish.image_logo_remote_url = img_url
        end

        if !parent.blank? && attrs["sizeable"]
          parent_dish = Dish.find_by name: parent
          adish.parent = parent_dish unless parent_dish.blank?
        end

        if adish.save
          result[:success].push adish
        else
          result[:fail].push({ attrs['name'] => 'Can not add this' })
        end

      rescue => e
        result[:fail].push({ attrs['name'] => e })
      end
    end

    result
  end
end
