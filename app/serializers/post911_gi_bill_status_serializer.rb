# frozen_string_literal: true

class Post911GIBillStatusSerializer
  include JSONAPI::Serializer

  set_id { '' }
  attribute :first_name
  attribute :last_name
  attribute :name_suffix
  attribute :date_of_birth
  attribute :va_file_number
  attribute :regional_processing_office
  attribute :eligibility_date
  attribute :delimiting_date
  attribute :percentage_benefit
  attribute :original_entitlement
  attribute :used_entitlement
  attribute :remaining_entitlement
  attribute :entitlement_transferred_out
  attribute :active_duty
  attribute :veteran_is_eligible
  attribute :enrollments

  def initialize(lighthouse_response, dgib_response)
    # TO-DO: Successfully merge TOE data
    resource = lighthouse_response.attributes.merge(dgib_response.attributes)
    super(resource)
  end
end
