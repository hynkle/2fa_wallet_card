require "toml"
require "xml"
require "base64"

CARD_SIZE = {2.125, 3.375}
MARGIN_VERTICAL = 0.25
MARGIN_HORIZONTAL = 0.25
SECTION_SEPARATOR_HEIGHT_AS_PROPORTION_OF_LINE_HEIGHT = 1
FONT_SIZE_AS_PROPORTION_OF_LINE_HEIGHT = 0.8

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

class Persona
  getter name
  getter image

  def initialize(name : String, image : Image)
    @name = name
    @image = image
  end
end

class Service
  getter persona
  getter image
  getter codes

  def initialize(persona : Persona, image : Image, codes = [] of String)
    @persona = persona
    @image = image
    @codes = codes
  end
end

config = TOML.parse(File.read("settings.toml"))

personas = {} of String => Persona
config["personas"].as(Hash).each do |(name, attrs)|
  attrs = attrs.as(Hash)
  image = Image.new(attrs["image"].as(String))
  personas[name] = Persona.new(name, image)
end

services = config["services"].as(Hash).map do |(identifier, attrs)|
  attrs = attrs.as(Hash)
  image = Image.new(attrs["image"].as(String))
  codes = attrs["codes"].as(Array).map {|code| code.as(String)}
  persona_name = attrs["persona"].as(String)
  persona = personas.fetch(persona_name)
  Service.new(persona, image, codes)
end

card_width, card_height = CARD_SIZE
content_height = card_height - MARGIN_VERTICAL * 2

number_of_codes = services.sum { |service| service.codes.size }
number_of_section_separators = services.size - 1
units_of_vertical_space = number_of_codes + number_of_section_separators * SECTION_SEPARATOR_HEIGHT_AS_PROPORTION_OF_LINE_HEIGHT
line_height = content_height.fdiv(units_of_vertical_space)
section_separator_height = line_height * SECTION_SEPARATOR_HEIGHT_AS_PROPORTION_OF_LINE_HEIGHT
image_height = image_width = line_height
font_size = line_height * FONT_SIZE_AS_PROPORTION_OF_LINE_HEIGHT

left_edge = MARGIN_HORIZONTAL
v_cursor = MARGIN_VERTICAL

svg = XML.build(indent: "  ") do |xml|
  viewbox = [0, 0, card_width, card_height].join(" ")
  xml.dtd("svg", "-//W3C//DTD SVG 1.1//EN", "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd")
  xml.element("svg", xmlns: "http://www.w3.org/2000/svg", "xmlns:xlink": "http://www.w3.org/1999/xlink", viewBox: viewbox) do
    # xml.element("rect", width: "100%", height: "100%", fill: "#EEEEEE") # background

    services.each.with_index do |service, service_idx|
      service.codes.each_with_index do |code, code_idx|
        xml.element("g", class: "row") do
          if code_idx == 0
            xml.element("image", x: left_edge, y: v_cursor, width: image_width, height: image_height, "xlink:href": service.image.data_uri)
            xml.element("image", x: left_edge + image_width * 1.2, y: v_cursor, width: image_width, height: image_height, "xlink:href": service.persona.image.data_uri)
          end

          xml.element("text", x: left_edge + (image_width * 1.2 * 2) + image_width * 0.5, y: v_cursor + line_height * 0.5, "font-size": font_size, "font-family": "DejaVu Sans Mono, monospace", "alignment-baseline": "middle") do
            xml.text code
          end
        end
        v_cursor += line_height # printed out a line, so need to move down by a line
      end
      v_cursor += section_separator_height
    end
  end
end

puts svg
