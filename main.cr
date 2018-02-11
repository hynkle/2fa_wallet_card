require "toml"
require "xml"
require "base64"

CARD_SIZE = {2.125, 3.375}

class Image
  getter source
  ROOT_DIR = "images"
  RASTER_FORMATS = ["png", "jpg", "jpeg"]
  VECTOR_FORMATS = ["svg"]
  SUPPORTED_FORMATS = RASTER_FORMATS + VECTOR_FORMATS

  def initialize(source : String)
    @source = source
  end

  def extension
    File.extname(source)[1..-1].downcase # lowercase extension without dot
  end

  def supported?
    SUPPORTED_FORMATS.include?(extension)
  end

  def raster?
    RASTER_FORMATS.include?(extension)
  end

  def vector?
    VECTOR_FORMATS.include?(extension)
  end

  def data_uri
    encoded_data = Base64.encode(data)
    "data:#{mime_type};base64,#{encoded_data}"
  end

  private def path
    File.join(ROOT_DIR, source)
  end

  private def data
    File.open(path, "rb") { |file| file.gets_to_end }
  end

  private def mime_type
    case extension
    when "png" then "image/png"
    when "jpg", "jpeg" then "image/jepg"
    when "svg" then "image/svg+xml"
    else raise "unknown mime type for extension #{extension}"
    end
  end
end

class Profile
  getter name
  getter image

  def initialize(name : String, image : Image)
    @name = name
    @image = image
  end
end

class Service
  getter profile
  getter image
  getter codes

  def initialize(profile : Profile, image : Image, codes = [] of String)
    @profile = profile
    @image = image
    @codes = codes
  end
end

config = TOML.parse(File.read("card.toml"))

profiles = {} of String => Profile
config["profiles"].as(Hash).each do |(name, attrs)|
  attrs = attrs.as(Hash)
  image = Image.new(attrs["image"].as(String))
  profiles[name] = Profile.new(name, image)
end

services = {} of String => Service
config["services"].as(Hash).each do |(identifier, attrs)|
  attrs = attrs.as(Hash)
  image = Image.new(attrs["image"].as(String))
  codes = attrs["codes"].as(Array).map {|code| code.as(String)}
  profile_name = attrs["profile"].as(String)
  profile = profiles.fetch(profile_name)
  services[identifier] = Service.new(profile, image, codes)
end

number_of_lines = services.sum { |(_, service)| service.codes.size }

svg = XML.build(indent: "  ") do |xml|
  card_width, card_height = CARD_SIZE
  viewbox = [0, 0, card_width, card_height].join(" ")
  line_height = card_height.fdiv(number_of_lines)
  image_height = image_width = (line_height * 0.8)

  xml.dtd("svg", "-//W3C//DTD SVG 1.1//EN", "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd")
  xml.element("svg", xmlns: "http://www.w3.org/2000/svg", "xmlns:xlink": "http://www.w3.org/1999/xlink", viewBox: viewbox) do
    xml.element("rect", width: "100%", height: "100%", fill: "#EEEEEE")

    line_number = 0
    services.each do |(_, service)|
      service.codes.each_with_index do |code, i|
        is_first = i == 0

        line_top = line_height * line_number

        xml.element("g", class: "row") do
          if i == 0
            xml.element("image", x: 0, y: line_top, width: image_width, height: image_height, "xlink:href": service.image.data_uri)
            xml.element("image", x: line_height, y: line_top, width: image_width, height: image_height, "xlink:href": service.profile.image.data_uri)
          end

          xml.element("text", x: line_height * 2, y: line_top + (line_height * 0.5), "font-size": line_height * 0.5, "font-family": "DejaVu Sans Mono", "alignment-baseline": "middle") do
            xml.text code
          end
        end

        line_number += 1
      end
    end
  end
end

puts svg
