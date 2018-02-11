require "toml"

class Profile
  getter name : String
  getter image : String

  def initialize(name, image)
    @name = name
    @image = image
  end
end

class Service
  getter profile
  getter image
  getter codes

  def initialize(profile : Profile, image : String, codes = [] of String)
    @profile = profile
    @image = image
    @codes = codes
  end
end

config = TOML.parse(File.read("card.toml"))

profiles = {} of String => Profile
config["profiles"].as(Hash).each do |(name, attrs)|
  attrs = attrs.as(Hash)
  image = attrs["image"].as(String)
  profiles[name] = Profile.new(name, image)
end

services = {} of String => Service
config["services"].as(Hash).each do |(identifier, attrs)|
  attrs = attrs.as(Hash)
  image = attrs["image"].as(String)
  codes = attrs["codes"].as(Array).map {|code| code.as(String)}
  profile_name = attrs["profile"].as(String)
  profile = profiles.fetch(profile_name)
  services[identifier] = Service.new(profile, image, codes)
end

