# frozen_string_literal: true

require 'map/security_token/service'

module V0
  class MapServicesController < SignIn::ServiceAccountApplicationController
    service_tag 'identity'
    before_action :set_deprecation_headers

    # POST /v0/map_services/:application/token
    def token
      icn = @service_account_access_token.user_attributes['icn']
      result = MAP::SecurityToken::Service.new.token(application: params[:application].to_sym, icn:, cache: false)

      render json: result, status: :ok
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout
      render json: sts_client_error, status: :bad_gateway
    rescue MAP::SecurityToken::Errors::ApplicationMismatchError
      render json: application_mismatch_error, status: :bad_request
    rescue MAP::SecurityToken::Errors::MissingICNError
      render json: missing_icn_error, status: :bad_request
    end

    private

    def sts_client_error
      {
        error: 'server_error',
        error_description: 'STS failed to return a valid token.'
      }
    end

    def application_mismatch_error
      {
        error: 'invalid_request',
        error_description: 'Application mismatch detected.'
      }
    end

    def missing_icn_error
      {
        error: 'invalid_request',
        error_description: 'Service account access token does not contain an ICN in `user_attributes` claim.'
      }
    end

    def set_deprecation_headers
      warn_deprecation

      response.headers['Deprecation'] = 'true'
      response.headers['Link'] = "<#{alternate_link}>; rel=\"alternate\""
      response.headers['Sunset'] = sunset_date
    end

    def warn_deprecation
      message =  "The endpoint 'v0/map_services/:application/token' is deprecated. " \
                 "Please use the 'sts/map_services/:application/token' endpoint instead."

      Rails.logger.warn("[V0][MapServicesController] warn: #{message}")
    end

    def alternate_link
      request.original_url.gsub('v0', 'sts')
    end

    def sunset_date
      Date.new(2024, 12, 31).httpdate
    end
  end
end
