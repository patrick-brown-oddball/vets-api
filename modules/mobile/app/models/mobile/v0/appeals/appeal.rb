# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    module Appeals
      class Appeal < Common::Resource
        AOJ_TYPES = Types::String.enum(
          'vba',
          'vha',
          'nca',
          'other'
        )

        LOCATION_TYPES = Types::String.enum(
          'aoj',
          'bva'
        )

        PROGRAM_AREA_TYPES = Types::String.enum(
          'compensation',
          'pension',
          'insurance',
          'loan_guaranty',
          'education',
          'vre',
          'medical',
          'burial',
          'bva',
          'other',
          'multiple'
        )

        ALERT_TYPES = Types::String.enum(
          'form9_needed',
          'scheduled_hearing',
          'hearing_no_show',
          'held_for_evidence',
          'cavc_option',
          'ramp_eligible',
          'ramp_ineligible',
          'decision_soon',
          'blocked_by_vso',
          'scheduled_dro_hearing',
          'dro_hearing_no_show'
        )

        EVENT_TYPES = Types::String.enum(
          'claim_decision',
          'nod',
          'soc',
          'form9',
          'ssoc',
          'certified',
          'hearing_held',
          'hearing_no_show',
          'bva_decision',
          'field_grant',
          'withdrawn',
          'ftr',
          'ramp',
          'death',
          'merged',
          'record_designation',
          'reconsideration',
          'vacated',
          'other_close',
          'cavc_decision',
          'ramp_notice',
          'transcript',
          'remand_return',
          'dro_hearing_held',
          'dro_hearing_cancelled',
          'dro_hearing_no_show'
        )

        LAST_ACTION_TYPES = Types::String.enum(
          'field_grant',
          'withdrawn',
          'allowed',
          'denied',
          'remand',
          'cavc_remand'
        )

        STATUS_TYPES = Types::String.enum(
          'scheduled_hearing',
          'pending_hearing_scheduling',
          'on_docket',
          'pending_certification_ssoc',
          'pending_certification',
          'pending_form9',
          'pending_soc',
          'stayed',
          'at_vso',
          'bva_development',
          'decision_in_progress',
          'bva_decision',
          'field_grant',
          'withdrawn',
          'ftr',
          'ramp',
          'death',
          'reconsideration',
          'other_close',
          'remand_ssoc',
          'remand',
          'merged'
        )

        attribute :id, Types::String
        attribute :appealIds, Types::Array.of(Types::String)
        attribute :active, Types::Bool
        attribute :alerts, Types::Array do
          attribute :type, ALERT_TYPES
          attribute :details, Types::Hash
        end
        attribute :aod, Types::Bool.optional
        attribute :aoj, AOJ_TYPES
        attribute :description, Types::String
        attribute :docket, Docket.optional
        attribute :events, Types::Array do
          attribute :type, EVENT_TYPES
          attribute :date, Types::Date
        end
        attribute :evidence, Types::Array.of(Evidence).optional
        attribute :incompleteHistory, Types::Bool
        attribute :issues, Types::Array do
          attribute :active, Types::Bool
          attribute :lastAction, LAST_ACTION_TYPES.optional
          attribute :description, Types::String
          attribute :diagnosticCode, Types::String.optional
          attribute :date, Types::Date
        end
        attribute :location, LOCATION_TYPES
        attribute :programArea, PROGRAM_AREA_TYPES
        attribute :status do
          attribute :type, STATUS_TYPES
          attribute :details, Types::Hash
        end
        attribute :type, Types::String
        attribute :updated, Types::DateTime
      end
    end
  end
end
