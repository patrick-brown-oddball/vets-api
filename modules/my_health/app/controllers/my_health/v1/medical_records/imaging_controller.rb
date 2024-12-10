# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class ImagingController < MrController
        include ActionController::Live

        before_action :set_study_id, only: %i[request_download images image dicom]

        def index
          render_resource(bb_client.list_imaging_studies)
        end

        def request_download
          render_resource(bb_client.request_study(@study_id))
        end

        def request_status
          render_resource(bb_client.get_study_status)
        end

        def images
          render_resource(bb_client.list_images(@study_id))
        end

        def image
          response.headers['Content-Type'] = 'image/jpeg'
          stream_data do |stream|
            bb_client.get_image(@study_id, params[:series_id].to_s, params[:image_id].to_s, header_callback, stream)
          end
        end

        def dicom
          filtered_headers = request.headers.select { |k, _v| k.start_with?('HTTP_') }
          puts 'HTTP Headers:'
          filtered_headers.each do |key, value|
            header_name = key.sub(/^HTTP_/, '').split('_').map(&:capitalize).join('-')
            puts "#{header_name}: #{value}"
          end
          range = request.headers['Range']
          if range.present?
            range_start, range_end = parse_range(range)
            response.status = 206 # Partial Content
            response.headers['Content-Range'] = "bytes #{range_start}-#{range_end}/*"
          end

          # Disable ETag manually to omit the "Content-Length" header for this streaming resource.
          # Otherwise the download/save dialog doesn't appear until after the file fully downloads.
          headers['ETag'] = nil

          response.headers['Content-Type'] = 'application/zip'
          stream_data do |stream|
            bb_client.get_dicom(@study_id, header_callback, range, stream)
          end
        end

        private

        def set_study_id
          @study_id = params[:id].to_s
        end

        def render_resource(resource)
          render json: resource.to_json
        end

        def header_callback
          lambda do |headers|
            headers.each do |k, v|
              next if %w[Content-Type Transfer-Encoding].include?(k)

              response.headers[k] = v if k.present?
            end
          end
        end

        def stream_data(&)
          chunk_stream = Enumerator.new(&)
          chunk_stream.each { |chunk| response.stream.write(chunk) }
        ensure
          response.stream.close if response.committed?
        end

        def parse_range(range_header)
          match = /bytes=(\d+)-(\d*)/.match(range_header)
          start_byte = match[1].to_i
          end_byte = match[2].present? ? match[2].to_i : nil
          [start_byte, end_byte]
        end
      end
    end
  end
end
