# frozen_string_literal: true

require 'lighthouse/facilities/v1/client'
require 'openssl'
require 'base64'
module V0
  # Application for the Program of Comprehensive Assistance for Family Caregivers (Form 10-10CG)
  class CaregiversAssistanceClaimsController < ApplicationController
    service_tag 'caregiver-application'

    AUDITOR = ::Form1010cg::Auditor.new

    # TODO: Regenerate and put these keys in configs somewhere
    PRIVATE_KEY = "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEAwviZmpP4bae1g5lAceQQgdmH1F8HnR9N+SjiVyX3jKq20JjC\nBZ1t8WzS+iji0LeihW5FHoASzAbm8FzM4IanDenCo2Dh8gtVVQoAo4F5Anb3j6Jj\nLGSPnK146MGxbQAqnv3w2ml2Qxq8Uo+Cno1YVWRuHJV6KVnMjnPaYiYkNJJlezPW\nr6Oyoza/eMf4UyhTczhIilp/rUb7+VILCNMDJT+MlWyYMgZQQaVnJmzbnDGWDnbM\nlsgdDSWjeZCajkPdTq4Rn7Do77DozcnCD9evFgpyukvgEjkdHrcvpQyj7So+U00Y\nYrwVGlyA+2xablxRyzwsJBw1nn/Au/J0FYrMvwIDAQABAoIBAA71KzTwiNzCGDWr\njQX6dQkT4GJQFLxJTwjq9IuytiOnYyrCABHrNSiSQeX+5gEU3YCMEvxsie9M0Ox8\nH3GoPZUJK9gEkkD9/ULEEi7OZjNktMhjBmW8+fGPXhkekayRmIjQZZPJXHvNx3M0\nCarSoDC+Pt5YL2I7E+uSgsdd3WWKT9dEFqVQMK02VnqyiHXng04mp8/MyU/+UYy/\nANRezinSnIT6WS7x3BS8vgMYJJIqLSu8tE5jwgltvuczTkPkhfHP2P/t42VUKzu1\nQ3UlHBN6PgrVnOxsY6Nl/b1BdbmLtIIMne+Z2Z10gFEAv+0R3LYyAgGde2eY5w6F\ndfNS51kCgYEA+q5VOZW4DLLOH41tEDvf7S21PiSMly0t1Nfn4NCdeTXhd7IPEYmy\nOnh6f+aFanfPsUb9uko6Y07MF4Ur0h32qNcL/1G9aMVrEH7qTceH6i/yK+IU+7FG\nkTrnvu9cLHBNLheG3JeCz/wzkms/m46gWvjgnyfnLiFv8J+VNuWTGekCgYEAxxuo\nd+llmjUyPG01bIlfB5v6iy9V6LtzqdAmL/zxoaFS6deVusxTA7jzgHuc4hoRU5p+\nl/4fMqtcSawqmHcVkeYsz89yOVIWFy3pvUsBum5W/xc7lIxUVBz1IxD9U4gpfrN0\nsy6dgVYphUR74/nSohXLPi9/aKrPxwsEizYEYGcCgYEAqYpmkX+07sGvrp9T9/rG\nw/556gGGJGil6qHrbZ0qI+RRDUcb8dyS8gCxuPcLnKpTia5dxDSXsLqGRhIHRSCG\nxkJLFu8Nj2KVup5bkSc1wSmUPCG311JaS7bvLa9tQ5DgYh//UgoWqtwDdS+b4XVg\n9qYEJSAztnte3frQTESQbKECgYAnyXcYvyL2dbrcKFaMocbDln+yYHsiTpMGU/nN\njRYb3kjbQaFB+qJ8E/FUs17eL6dWtYCmjrldPrDqZ+T7IpDE3uIFhMamfai8aQhU\nMzDdOD9aKiJVxNT1GfRCVZrJnmPsVZ/0TlRbDASwBMdc/wcALKq4enVTTQ7ID4OQ\n7fJh8QKBgQD5E805SrOG/Yg1pM+XmvR7JWlKuk4YzVgplGeyga7NIdoVVw8psqWZ\nQpdMa8i6TunNGLXBr90UJFL+rJWJsMSXqIj3hTOUU54LxC0IrI5dn62yfpjFNLqq\nbi2+m8K5Sd7QYUHfRUT/1P0CVpxJMj+83fnGo0Bewp0C8oL5PWoHdA==\n-----END RSA PRIVATE KEY-----\n"
    PUBLIC_KEY = "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwviZmpP4bae1g5lAceQQ\ngdmH1F8HnR9N+SjiVyX3jKq20JjCBZ1t8WzS+iji0LeihW5FHoASzAbm8FzM4Ian\nDenCo2Dh8gtVVQoAo4F5Anb3j6JjLGSPnK146MGxbQAqnv3w2ml2Qxq8Uo+Cno1Y\nVWRuHJV6KVnMjnPaYiYkNJJlezPWr6Oyoza/eMf4UyhTczhIilp/rUb7+VILCNMD\nJT+MlWyYMgZQQaVnJmzbnDGWDnbMlsgdDSWjeZCajkPdTq4Rn7Do77DozcnCD9ev\nFgpyukvgEjkdHrcvpQyj7So+U00YYrwVGlyA+2xablxRyzwsJBw1nn/Au/J0FYrM\nvwIDAQAB\n-----END PUBLIC KEY-----\n"

    skip_before_action :authenticate
    before_action :load_user, only: :create

    before_action :record_submission_attempt, only: :create
    before_action :initialize_claim, only: %i[create download_pdf]

    rescue_from ::Form1010cg::Service::InvalidVeteranStatus, with: :backend_service_outage

    def create
      if @claim.valid?
        Sentry.set_tags(claim_guid: @claim.guid)
        auditor.record_caregivers(@claim)

        ::Form1010cg::Service.new(@claim).assert_veteran_status

        @claim.save!
        ::Form1010cg::SubmissionJob.perform_async(@claim.id)
        render json: ::Form1010cg::ClaimSerializer.new(@claim)
      else
        PersonalInformationLog.create!(data: { form: @claim.parsed_form }, error_class: '1010CGValidationError')
        auditor.record(:submission_failure_client_data, claim_guid: @claim.guid, errors: @claim.errors.messages)
        raise(Common::Exceptions::ValidationErrors, @claim)
      end
    rescue => e
      unless e.is_a?(Common::Exceptions::ValidationErrors) || e.is_a?(::Form1010cg::Service::InvalidVeteranStatus)
        Rails.logger.error('CaregiverAssistanceClaim: error submitting claim',
                           { saved_claim_guid: @claim.guid, error: e })
      end
      raise e
    end

    # If we were unable to submit the user's claim digitally, we allow them to the download
    # the 10-10CG PDF, pre-filled with their data, for them to mail in.
    def download_pdf
      source_file_path = if Flipper.enabled?(:caregiver1010)
                           @claim.to_pdf(SecureRandom.uuid,
                                         sign: false)
                         else
                           PdfFill::Filler.fill_form(
                             @claim, SecureRandom.uuid, sign: false
                           )
                         end

      client_file_name = file_name_for_pdf(@claim.veteran_data)
      file_contents    = File.read(source_file_path)

      auditor.record(:pdf_download)

      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    ensure
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    def facilities
      lighthouse_facilities = lighthouse_facilities_service.get_paginated_facilities(lighthouse_facilities_params)
      render(json: lighthouse_facilities)
    end

    private

    # TODO: move this to it's own service or something
    def decrypt(encrypted_base64)
      encrypted_data = Base64.decode64(encrypted_base64)
      private_key = OpenSSL::PKey::RSA.new(PRIVATE_KEY)

      begin
        private_key.decrypt(encrypted_data, rsa_padding_mode: 'oaep', rsa_oaep_md: 'sha256')
      rescue OpenSSL::PKey::PKeyError
        Rails.logger.error('CaregiverAssistanceClaimsController: error decrypting params',
                           { error: e })
      end
    end

    def lighthouse_facilities_service
      @lighthouse_facilities_service ||= Lighthouse::Facilities::V1::Client.new
    end

    def lighthouse_facilities_params
      permitted_params = params.permit(
        lighthouse_facilities_params_array
      ).to_h

      permitted_params[:lat] = decrypt(permitted_params[:lat]) if permitted_params[:lat]
      permitted_params[:long] = decrypt(permitted_params[:long]) if permitted_params[:long]

      permitted_params
    end

    def lighthouse_facilities_params_array
      [:zip,
       :state,
       :lat,
       :lat_iv,
       :long,
       :long_iv,
       :radius,
       :visn,
       :type,
       :mobile,
       :page,
       :per_page,
       :facilityIds,
       { services: [],
         bbox: [] }]
    end

    def record_submission_attempt
      auditor.record(:submission_attempt)
    end

    def form_submission
      params.require(:caregivers_assistance_claim).require(:form)
    rescue => e
      auditor.record(:submission_failure_client_data, errors: [e.original_message])
      raise e
    end

    def initialize_claim
      @claim = SavedClaim::CaregiversAssistanceClaim.new(form: form_submission)
    end

    def file_name_for_pdf(veteran_data)
      veteran_name = veteran_data.try(:[], 'fullName')
      first_name = veteran_name.try(:[], 'first') || 'First'
      last_name = veteran_name.try(:[], 'last') || 'Last'
      "10-10CG_#{first_name}_#{last_name}.pdf"
    end

    def backend_service_outage
      auditor.record(
        :submission_failure_client_qualification,
        claim_guid: @claim.guid
      )

      render_errors Common::Exceptions::ServiceOutage.new(nil, detail: 'Backend Service Outage')
    end

    def auditor
      self.class::AUDITOR
    end
  end
end
