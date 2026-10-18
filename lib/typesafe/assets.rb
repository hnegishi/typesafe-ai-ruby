# frozen_string_literal: true

module TypeSafe
  # Turns the images in a request into the assets map sent with it.
  #
  # Images placed directly in state, instructions or criteria are collected while the request
  # is normalized. Images written into text through their reference, or sent under a name of
  # your choice, are passed in assets:. Every reference in the request must resolve to an
  # image, and every attached image must be referenced, or the API rejects the request.
  module Assets
    MAX_REFERENCE_BYTES = 1024

    module_function

    # Normalize the assets: argument into reference => Image.
    def attach(value)
      case value
      when nil then {}
      when Image then { value.reference => value }
      when Array then value.to_h { |image| [image!(image).reference, image] }
      when Hash then value.to_h { |name, image| [reference!(name), image!(image)] }
      else raise ValidationError, "assets must be an Image, an Array of images, or a Hash of reference => Image"
      end
    end

    # Merge collected and attached images and check that references and assets match up.
    # +json+ is the encoded request body without the assets map.
    def resolve(collected, attached, json)
      assets = collected.to_h { |image| [image.reference, image] }.merge(attached)
      json.scan(Image::REFERENCE_PATTERN).uniq.each do |reference|
        next if assets.key?(reference)

        raise ValidationError, "#{reference} refers to an image that is not attached to the request; pass it in assets:"
      end
      attached.each_key do |reference|
        next if json.include?(escape(reference))

        raise ValidationError, "asset #{reference.inspect} is not referenced anywhere in the request"
      end
      assets.each_value(&:validate!)
    end

    def image!(value)
      return value if value.is_a?(Image)

      raise ValidationError, "assets must contain TypeSafe::Image values, got #{value.class}"
    end

    def reference!(name)
      reference = name.to_s
      raise ValidationError, "asset references must not be blank" if reference.strip.empty?
      if reference.bytesize > MAX_REFERENCE_BYTES
        raise ValidationError, "asset reference is #{reference.bytesize} bytes; the limit is #{MAX_REFERENCE_BYTES}"
      end

      reference
    end

    # A reference as it appears inside a JSON string.
    def escape(reference)
      JSON.generate(reference)[1...-1]
    end
  end
end
