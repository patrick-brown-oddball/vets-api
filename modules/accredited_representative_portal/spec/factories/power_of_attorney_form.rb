# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_form, class: 'AccreditedRepresentativePortal::PowerOfAttorneyForm' do
    association :power_of_attorney_request, factory: :power_of_attorney_request
    data_ciphertext { 'Test encrypted data' }
    city_bidx { Faker::Alphanumeric.alphanumeric(number: 44) }
    state_bidx { Faker::Alphanumeric.alphanumeric(number: 44) }
    zipcode_bidx { Faker::Alphanumeric.alphanumeric(number: 44) }
    encrypted_kms_key { SecureRandom.hex(16) }
  end
end
