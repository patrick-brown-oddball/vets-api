# frozen_string_literal: true

require 'disability_compensation/providers/rated_disabilities/rated_disabilities_provider'
require 'lighthouse/veteran_verification/service'

class LighthouseRatedDisabilitiesProvider
  include RatedDisabilitiesProvider
  def initialize(current_user)
    @current_user = current_user
    @service = VeteranVerification::Service.new
  end

  def get_rated_disabilities
    auth_params = {
      launch: Base64.encode64(JSON.generate({ patient: @current_user.icn.to_s }))
    }
    data = @service.get_rated_disabilities(nil, auth_params)
    transform(data['data']['attributes']['individual_ratings'])
  end

  def transform(data)
    rated_disabilities =
      data.map do |rated_disability|
        DisabilityCompensation::ApiProvider::RatedDisability.new(
          name: rated_disability['diagnostic_type_name'],
          decision_code: decision_code_transform(rated_disability['decision']),
          decision_text: rated_disability['description'],
          diagnostic_code: rated_disability['diagnostic_type_code'].to_i,
          effective_date: rated_disability['effective_date'],
          rated_disability_id: 0,
          rating_decision_id: 0,
          rating_percentage: rated_disability['rating_percentage'],
          related_disability_date: DateTime.now
        )
      end
    DisabilityCompensation::ApiProvider::RatedDisabilitiesResponse.new(rated_disabilities:)
  end

  def decision_code_transform(decision_code_text)
    if decision_code_text&.downcase == 'Service Connected'.downcase
      'SVCCONNCTED'
    else
      'NOTSVCCON'
    end
  end
end
