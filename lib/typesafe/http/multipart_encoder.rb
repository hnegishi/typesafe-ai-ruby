# frozen_string_literal: true

require "securerandom"

module TypeSafe
  module HTTP
    # Encodes a multipart/form-data body: the JSON request as the first part, named
    # "request", followed by one file part per image asset.
    class MultipartEncoder
      Part = Struct.new(:name, :content_type, :content, keyword_init: true)
      Encoded = Struct.new(:body, :content_type, :summary, keyword_init: true)

      # Encode a request body Hash with its assets (reference => Image). The assets map in the
      # JSON points each reference at its file part, named asset-0, asset-1 and so on.
      def self.build(body, assets)
        parts = parts_for(assets)
        entries = assets.keys.zip(parts).to_h { |ref, part| [ref, { "type" => "image", "part" => part.name }] }
        json = JSON.generate(body.merge("assets" => entries))
        encoder = new
        Encoded.new(body: encoder.encode(json, parts), content_type: encoder.content_type,
                    summary: summary_for(json, parts))
      end

      def self.parts_for(assets)
        assets.each_value.with_index.map do |image, index|
          Part.new(name: "asset-#{index}", content_type: image.content_type, content: image.bytes)
        end
      end

      def self.summary_for(json, parts)
        "#{json} + #{parts.map { |p| "#{p.name} (#{p.content_type}, #{p.content.bytesize} bytes)" }.join(", ")}"
      end

      attr_reader :boundary

      def initialize(boundary: SecureRandom.hex(16))
        @boundary = boundary
      end

      def content_type
        "multipart/form-data; boundary=#{boundary}"
      end

      # The encoded body as a binary String.
      def encode(json, parts)
        body = +"".b
        append(body, "request", "application/json", json)
        parts.each { |part| append(body, part.name, part.content_type, part.content, filename: part.name) }
        body << "--#{boundary}--\r\n"
      end

      private

      def append(body, name, content_type, content, filename: nil)
        disposition = %(form-data; name="#{name}")
        disposition += %(; filename="#{filename}") if filename
        body << "--#{boundary}\r\n"
        body << "Content-Disposition: #{disposition}\r\n"
        body << "Content-Type: #{content_type}\r\n\r\n"
        body << content.b
        body << "\r\n"
      end
    end
  end
end
