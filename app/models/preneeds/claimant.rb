# frozen_string_literal: true
require 'preneeds/models/attribute_types/xml_date'
require 'common/models/base'

module Preneeds
  class Claimant < Preneeds::Base
    attribute :date_of_birth, String
    attribute :desired_cemetery, String
    attribute :email, String
    attribute :phone_number, String
    attribute :relationship_to_vet, String
    attribute :ssn, String

    attribute :name, Preneeds::FullName
    attribute :address, Preneeds::Address

    def as_eoas
      hash = {
        address: address&.as_eoas, dateOfBirth: date_of_birth, desiredCemetery: desired_cemetery,
        email: email, name: name&.as_eoas, phoneNumber: phone_number,
        relationshipToVet: relationship_to_vet, ssn: eoas_ssn
      }

      [:email, :phoneNumber].each { |key| hash.delete(key) if hash[key].blank? }
      hash
    end

    def self.permitted_params
      [
        :date_of_birth, :desired_cemetery, :email, :completing_reason, :phone_number, :relationship_to_vet, :ssn,
        address: Preneeds::Address.permitted_params, name: Preneeds::FullName.permitted_params
      ]
    end

    private

    def eoas_ssn
      "#{ssn[0..2]}-#{ssn[3..4]}-#{ssn[5..8]}"
    end
  end
end
