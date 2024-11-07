# frozen_string_literal: true

require 'dgib/response'

module Vye
  module DGIB
    module ClaimantStatus
      class Response < Vye::DGIB::Response
        attribute :claimant_id, Integer
        attribute :delimiting_date, String
        attribute :verified_details, Array
        attribute :payment_on_hold, Boolean

        def initialize(status, response = nil)
          attributes = {
            claimant_id: response.body['claimant_id'],
            delimiting_date: response.body['delimiting_date'],
            verified_details: response.body['verified_details'],
            payment_on_hold: response.body['payment_on_hold']
          }

          super(status, attributes)
        end
      end
    end
  end
end
