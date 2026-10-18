# frozen_string_literal: true

require "securerandom"

module TypeSafe
  # A PNG or JPEG image to send with a request. Images are an experimental API feature and
  # need the :images danger zone turned on.
  #
  # Build one from file bytes, a path (read when the request is sent), or base64 text, then
  # place it anywhere text can go in state, instructions or criteria. Each image is sent once
  # under its reference, and to_s returns that reference so an image can be written into a
  # sentence; images used that way must be passed in assets: as well.
  #
  # For example:
  #   door = TypeSafe::Image.open("door-camera.jpg")
  #   client.system_one(
  #     state: { door: door },
  #     questions: { person: { type: :noul, instructions: "Is there a person in `door`?" } },
  #     danger_zone: :images
  #   )
  class Image
    MAX_BYTES = 16 * 1024 * 1024
    REFERENCE_PATTERN = /<image:[0-9a-f]{32}>/
    SIGNATURES = {
      "image/png" => "\x89PNG\r\n\x1a\n".b,
      "image/jpeg" => "\xFF\xD8\xFF".b
    }.freeze

    # The unique string this image is sent under, such as "<image:3f2a...>".
    attr_reader :reference
    # The path the image is read from, when built with Image.open.
    attr_reader :path

    # An image read from a file when the request is sent.
    def self.open(path)
      new(nil, path: path.to_s)
    end

    # An image from base64 text, such as an upload. Whitespace is ignored; a data: prefix is not allowed.
    def self.from_base64(text)
      raise ValidationError, "base64 image data must be a String, got #{text.class}" unless text.is_a?(String)

      compact = text.gsub(/\s+/, "")
      bytes = compact.unpack1("m0") # strict base64, the standard alphabet with padding
      new(bytes)
    rescue ArgumentError
      raise ValidationError, "base64 image data is not valid base64"
    end

    # Whether a string is an image reference.
    def self.reference?(string)
      string.is_a?(String) && REFERENCE_PATTERN.match?(string) && string.match(REFERENCE_PATTERN)[0] == string
    end

    def initialize(bytes = nil, path: nil)
      raise ArgumentError, "pass either image bytes or a path" if bytes.nil? == path.nil?

      @path = path
      @bytes = bytes.nil? ? nil : validate_bytes(bytes)
      @reference = "<image:#{SecureRandom.hex(16)}>"
    end

    # The image file bytes, read from the path on first use.
    def bytes
      @bytes ||= validate_bytes(read_file)
    end

    def bytesize
      bytes.bytesize
    end

    # "image/png" or "image/jpeg", from the file signature.
    def content_type
      SIGNATURES.find { |_, signature| bytes.start_with?(signature) }&.first ||
        raise(ValidationError, "#{describe} is not a PNG or JPEG file")
    end

    # "png" or "jpeg".
    def format
      content_type.delete_prefix("image/")
    end

    # Check that the bytes are a PNG or JPEG within the size limit; raises ValidationError otherwise.
    def validate!
      content_type
      self
    end

    def to_s
      reference
    end

    def to_json(*args)
      reference.to_json(*args)
    end

    def inspect
      "#<#{self.class.name} #{path ? path.inspect : "#{@bytes&.bytesize || "?"} bytes"} #{reference}>"
    end

    private

    def read_file
      File.binread(path)
    rescue SystemCallError => e
      raise ValidationError, "cannot read image #{path.inspect}: #{e.message}"
    end

    def validate_bytes(data)
      raise ValidationError, "image data must be a String of bytes, got #{data.class}" unless data.is_a?(String)
      raise ValidationError, "#{describe} is empty" if data.empty?
      if data.bytesize > MAX_BYTES
        raise ValidationError, "#{describe} is #{data.bytesize} bytes; the limit is #{MAX_BYTES}"
      end

      data.b.freeze
    end

    def describe
      path ? "image #{path.inspect}" : "image data"
    end
  end
end
