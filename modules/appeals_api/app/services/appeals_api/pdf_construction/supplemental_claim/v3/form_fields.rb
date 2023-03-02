# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module V3
        class FormFields
          FIELD_NAMES = {
            veteran_middle_initial: 'form1[0].#subform[2].VeteransMiddleInitial1[0]',
            veteran_ssn_first_three: 'form1[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]',
            veteran_ssn_middle_two: 'form1[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]',
            veteran_ssn_last_four: 'form1[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]',
            veteran_file_number: 'form1[0].#subform[2].VAFileNumber[0]',
            veteran_dob_day: 'form1[0].#subform[2].DOBday[0]',
            veteran_dob_month: 'form1[0].#subform[2].DOBmonth[0]',
            veteran_dob_year: 'form1[0].#subform[2].DOByear[0]',
            veteran_service_number: 'form1[0].#subform[2].VeteransServiceNumber[0]',
            veteran_insurance_policy_number: 'form1[0].#subform[2].InsurancePolicyNumber[0]',
            claimant_middle_initial: 'form1[0].#subform[2].ClaimantsMiddleInitial1[0]',
            signing_appellant_state_code: 'form1[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]',
            signing_appellant_country_code: 'form1[0].#subform[2].CurrentMailingAddress_Country[0]',
            international_phone: 'form1[0].#subform[2].TELEPHONE[0]',
            phone_area_code: 'form1[0].#subform[2].Daytime1[0]',
            phone_prefix: 'form1[0].#subform[2].Daytime2[0]',
            phone_line_number: 'form1[0].#subform[2].Daytime3[0]',
            claimant_type_code: 'form1[0].#subform[2].RadioButtonList[1]',
            benefit_type_code: 'form1[0].#subform[2].RadioButtonList[0]',
            form_5103_notice_acknowledged: 'form1[0].#subform[3].TIME1230TO2PM[0]',
            veteran_claimant_rep_date_signed: 'form1[0].#subform[3].DATESIGNED[0]',
            alternate_signer_date_signed: 'form1[0].#subform[3].DATESIGNED[1]'
          }.freeze

          def initialize
            FIELD_NAMES.each { |field, name| define_singleton_method(field) { name } }
          end

          # rubocop:disable Metrics/MethodLength
          def boxes
            {
              veteran_first_name: { at: [-1, 601.6], width: 201, height: 13.9 },
              veteran_last_name: { at: [235.5, 601.5], width: 304, height: 15.3 },
              claimant_first_name: { at: [-1, 496.5], width: 200, height: 14.4 },
              claimant_last_name: { at: [236, 497.25], width: 302, height: 14.7 },
              claimant_type_other_text: { at: [434, 470], width: 105 },
              signing_appellant_number_and_street: { at: [21.4, 436.5], width: 516, height: 13.2 },
              signing_appellant_city: { at: [193.3, 415.3], width: 309, height: 13.7 },
              signing_appellant_zip_code: { at: [290.7, 393.4], width: 82, height: 14.7 },
              international_phone: { at: [324, 361], width: 200, height: 14 },
              signing_appellant_email: { at: [-1, 333.7], width: 524, height: 12.9 },
              contestable_issues: Structure::MAX_ISSUES_ON_MAIN_FORM.times.map do |i|
                { at: [-5, 173 - (29.5 * i)], width: 402, height: 22, valign: :top }
              end,
              soc_dates: Structure::MAX_ISSUES_ON_MAIN_FORM.times.map do |i|
                { at: [414, 182 - (29.5 * i)], width: 120, height: 15 }
              end,
              decision_dates: Structure::MAX_ISSUES_ON_MAIN_FORM.times.map do |i|
                { at: [414, 164 - (29.5 * i)], width: 120, height: 22, valign: :top }
              end,
              new_evidence_locations: Structure::MAX_ISSUES_ON_MAIN_FORM.times.map do |i|
                { at: [-5, 589.5 - (33.8 * i)], width: 404, height: 28, valign: :top }
              end,
              new_evidence_dates: Structure::MAX_ISSUES_ON_MAIN_FORM.times.map do |i|
                { at: [414, 591 - (34 * i)], width: 116, height: 32.5, size: 10, valign: :top }
              end,
              veteran_claimant_rep_signature: { at: [-3, 266], width: 408, valign: :top },
              alternate_signer_signature: { at: [-3, 102], width: 408, height: 12, valign: :top }
            }.freeze
          end
          # rubocop:enable Metrics/MethodLength
        end
      end
    end
  end
end
