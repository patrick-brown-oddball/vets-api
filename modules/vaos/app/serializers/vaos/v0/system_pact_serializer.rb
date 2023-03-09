# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'jsonapi/serializer'

module VAOS
  module V0
    class SystemPactSerializer
      include JSONAPI::Serializer

      set_id :provider_sid
      attributes :facility_id,
                 :possible_primary,
                 :provider_position,
                 :provider_sid,
                 :staff_name,
                 :team_name,
                 :team_purpose,
                 :team_sid,
                 :title
    end
  end
end
# :nocov:
