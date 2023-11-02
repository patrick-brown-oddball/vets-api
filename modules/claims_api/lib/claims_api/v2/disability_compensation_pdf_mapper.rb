# frozen_string_literal: true

module ClaimsApi
  module V2
    class DisabilityCompensationPdfMapper # rubocop:disable Metrics/ClassLength
      NATIONAL_GUARD_COMPONENTS = {
        'National Guard' => 'NATIONAL_GUARD',
        'Reserves' => 'RESERVES'
      }.freeze

      SERVICE_COMPONENTS = {
        'National Guard' => 'NATIONAL_GUARD',
        'Reserves' => 'RESERVES',
        'Active' => 'ACTIVE'
      }.freeze

      DATE_FORMATS = {
        10 => :convert_date_string_to_format_mdy,
        7 => :convert_date_string_to_format_my,
        4 => :convert_date_string_to_format_yyyy
      }.freeze

      def initialize(auto_claim, pdf_data, auth_headers, middle_initial)
        @auto_claim = auto_claim
        @pdf_data = pdf_data
        @auth_headers = auth_headers&.deep_symbolize_keys
        @middle_initial = middle_initial
      end

      def map_claim
        claim_attributes
        toxic_exposure_attributes
        homeless_attributes
        veteran_info
        chg_addr_attributes if @auto_claim['changeOfAddress'].present?
        service_info
        disability_attributes
        treatment_centers
        get_service_pay
        direct_deposit_information
        deep_compact(@pdf_data[:data][:attributes])

        @pdf_data
      end

      def claim_attributes
        @pdf_data[:data][:attributes] = @auto_claim&.deep_symbolize_keys
        @pdf_data[:data][:attributes].delete(:claimantCertification)
        claim_date_and_signature
        claim_process_type

        @pdf_data
      end

      def claim_process_type
        if @auto_claim&.dig('claimProcessType') == 'BDD_PROGRAM'
          @pdf_data[:data][:attributes][:claimProcessType] = 'BDD_PROGRAM_CLAIM'
        end

        @pdf_data
      end

      def homeless_attributes
        if @auto_claim&.dig('homeless').present?
          @pdf_data[:data][:attributes][:homelessInformation] = @auto_claim&.dig('homeless')&.deep_symbolize_keys

          homeless_info = @pdf_data&.dig(:data, :attributes, :homelessInformation)
          new_homeless_info = @pdf_data&.dig(:data, :attributes, :homeless)

          homeless_phone_info(homeless_info, new_homeless_info) if homeless_info && new_homeless_info
          if @pdf_data[:data][:attributes][:homelessInformation][:pointOfContactNumber].empty?
            @pdf_data[:data][:attributes][:homelessInformation].delete(:pointOfContactNumber)
          end
          homeless_at_risk_or_currently
        end
        @pdf_data[:data][:attributes].delete(:homeless)

        @pdf_data
      end

      def homeless_phone_info(homeless_info, new_homeless_info)
        poc_phone = new_homeless_info&.dig(:pointOfContactNumber, :telephone)
        poc_international = new_homeless_info&.dig(:pointOfContactNumber, :internationalTelephone)

        phone = convert_phone(poc_phone) if poc_phone.present?
        international = convert_phone(poc_international) if poc_international.present?

        homeless_info[:pointOfContactNumber][:telephone] = phone unless phone.nil?
        homeless_info[:pointOfContactNumber].delete(:telephone) if phone.nil?
        homeless_info[:pointOfContactNumber][:internationalTelephone] = international unless international.nil?
        homeless_info[:pointOfContactNumber].delete(:internationalTelephone) if international.nil?
      end

      def homeless_at_risk_or_currently
        at_risk = @auto_claim&.dig('homeless', 'riskOfBecomingHomeless', 'livingSituationOptions').present?
        currently = @auto_claim&.dig('homeless', 'pointOfContact').present?

        if currently && !at_risk
          @pdf_data[:data][:attributes][:homelessInformation].merge!(areYouCurrentlyHomeless: 'YES')
        else
          homeless = @pdf_data[:data][:attributes][:homelessInformation].present?
          @pdf_data[:data][:attributes][:homelessInformation].merge!(areYouAtRiskOfBecomingHomeless: 'YES') if homeless
        end

        @pdf_data
      end

      def chg_addr_attributes # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        @pdf_data[:data][:attributes][:changeOfAddress] =
          @auto_claim&.dig('changeOfAddress')&.deep_symbolize_keys

        country = @pdf_data[:data][:attributes][:changeOfAddress][:country]
        abbr_country = country == 'USA' ? 'US' : country
        @pdf_data[:data][:attributes][:changeOfAddress].merge!(
          newAddress: { country: abbr_country }
        )
        @pdf_data[:data][:attributes][:changeOfAddress].merge!(
          effectiveDates: {
            start:
            regex_date_conversion(@pdf_data[:data][:attributes][:changeOfAddress][:dates][:beginDate])
          }
        )
        if @pdf_data[:data][:attributes][:changeOfAddress][:dates][:endDate].present?
          @pdf_data[:data][:attributes][:changeOfAddress][:effectiveDates][:end] =
            regex_date_conversion(@pdf_data[:data][:attributes][:changeOfAddress][:dates][:endDate])
        end

        change_addr = @pdf_data[:data][:attributes][:changeOfAddress]
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:numberAndStreet] =
          concatenate_address(change_addr[:addressLine1], change_addr[:addressLine2], change_addr[:addressLine3])

        city = @pdf_data[:data][:attributes][:changeOfAddress][:city]
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:city] = city
        state = @pdf_data[:data][:attributes][:changeOfAddress][:state]
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:state] = state
        chg_addr_zip
        @pdf_data[:data][:attributes][:changeOfAddress][:dates].delete(:beginDate)
        @pdf_data[:data][:attributes][:changeOfAddress][:dates].delete(:endDate)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:dates)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:addressLine1)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:addressLine2)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:addressLine3)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:numberAndStreet)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:apartmentOrUnitNumber)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:city)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:state)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:zipFirstFive)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:zipLastFour)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:country)

        @pdf_data
      end

      def chg_addr_zip
        zip_first_five = (@auto_claim&.dig('changeOfAddress', 'zipFirstFive') || '')
        zip_last_four = (@auto_claim&.dig('changeOfAddress', 'zipLastFour') || '')
        zip = if zip_last_four.present?
                "#{zip_first_five}-#{zip_last_four}"
              else
                zip_first_five
              end
        addr = @pdf_data&.dig(:data, :attributes, :identificationInformation, :mailingAddress).present?
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress].merge!(zip:) if addr
      end

      def toxic_exposure_attributes
        toxic = @auto_claim&.dig('toxicExposure').present?
        if toxic
          @pdf_data[:data][:attributes].merge!(
            exposureInformation: { toxicExposure: @auto_claim&.dig('toxicExposure')&.deep_symbolize_keys }
          )
          gulfwar_hazard
          herbicide_hazard
          additional_exposures
          multiple_exposures
          @pdf_data[:data][:attributes].delete(:toxicExposure)

          @pdf_data
        end
      end

      # rubocop:disable Layout/LineLength
      def gulfwar_hazard
        gulf = @pdf_data&.dig(:data, :attributes, :toxicExposure, :gulfWarHazardService).present?
        if gulf
          gulfwar_service_dates_begin = @pdf_data[:data][:attributes][:toxicExposure][:gulfWarHazardService][:serviceDates][:beginDate]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:serviceDates][:start] =
            regex_date_conversion(gulfwar_service_dates_begin)
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:serviceDates].delete(:beginDate)
          gulfwar_service_dates_end = @pdf_data[:data][:attributes][:toxicExposure][:gulfWarHazardService][:serviceDates][:endDate]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:serviceDates][:end] =
            regex_date_conversion(gulfwar_service_dates_end)
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:serviceDates].delete(:endDate)
          served_in_gulf_war_hazard_locations = @pdf_data[:data][:attributes][:toxicExposure][:gulfWarHazardService][:servedInGulfWarHazardLocations]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:servedInGulfWarHazardLocations] =
            served_in_gulf_war_hazard_locations ? 'YES' : 'NO'
        end
      end

      def herbicide_hazard
        herb = @pdf_data&.dig(:data, :attributes, :toxicExposure, :herbicideHazardService).present?
        if herb
          herbicide_service_dates_begin = @pdf_data[:data][:attributes][:toxicExposure][:herbicideHazardService][:serviceDates][:beginDate]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:serviceDates][:start] =
            regex_date_conversion(herbicide_service_dates_begin)
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:serviceDates].delete(:beginDate)
          herbicide_service_dates_end = @pdf_data[:data][:attributes][:toxicExposure][:herbicideHazardService][:serviceDates][:endDate]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:serviceDates][:end] =
            regex_date_conversion(herbicide_service_dates_end)
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:serviceDates].delete(:endDate)
          served_in_herbicide_hazard_locations = @pdf_data[:data][:attributes][:toxicExposure][:herbicideHazardService][:servedInHerbicideHazardLocations]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:servedInHerbicideHazardLocations] =
            served_in_herbicide_hazard_locations ? 'YES' : 'NO'
        end
      end

      def additional_exposures
        add = @pdf_data&.dig(:data, :attributes, :toxicExposure, :additionalHazardExposures).present?
        if add
          additional_exposure_dates_begin = @pdf_data[:data][:attributes][:toxicExposure][:additionalHazardExposures][:exposureDates][:beginDate]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:additionalHazardExposures][:exposureDates][:start] =
            regex_date_conversion(additional_exposure_dates_begin)
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:additionalHazardExposures][:exposureDates].delete(:beginDate)
          additional_exposure_dates_end = @pdf_data[:data][:attributes][:toxicExposure][:additionalHazardExposures][:exposureDates][:endDate]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:additionalHazardExposures][:exposureDates][:end] =
            regex_date_conversion(additional_exposure_dates_end)
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:additionalHazardExposures][:exposureDates].delete(:endDate)
        end
      end

      def multiple_exposures
        multi = @pdf_data&.dig(:data, :attributes, :toxicExposure, :multipleExposures).present?
        if multi
          @pdf_data[:data][:attributes][:toxicExposure][:multipleExposures].each_with_index do |exp, index|
            multiple_service_dates_begin = exp[:exposureDates][:beginDate]
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][index][:exposureDates][:start] = regex_date_conversion(multiple_service_dates_begin)
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][index][:exposureDates].delete(:beginDate)
            multiple_service_dates_end = exp[:exposureDates][:endDate]
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][index][:exposureDates][:end] = regex_date_conversion(multiple_service_dates_end)
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][index][:exposureDates].delete(:endDate)
          end
        end
        @pdf_data
      end

      def deep_compact(hash)
        hash.each { |_, value| deep_compact(value) if value.is_a? Hash }
        hash.select! { |_, value| exists?(value) }
        hash
      end

      def exists?(value)
        if [true, false].include?(value)
          true
        elsif value.is_a?(String) || value.is_a?(Hash)
          !value.empty?
        else
          !value.nil?
        end
      end

      def veteran_info # rubocop:disable Metrics/MethodLength
        @pdf_data[:data][:attributes].merge!(
          identificationInformation: @auto_claim&.dig('veteranIdentification')&.deep_symbolize_keys
        )
        @pdf_data[:data][:attributes][:identificationInformation][:vaFileNumber] = @auth_headers[:va_eauth_birlsfilenumber]
        vet_number = @pdf_data[:data][:attributes][:identificationInformation][:veteranNumber].present?
        if vet_number
          phone = convert_phone(@pdf_data[:data][:attributes][:identificationInformation][:veteranNumber][:telephone])
          international_telephone =
            convert_phone(@pdf_data[:data][:attributes][:identificationInformation][:veteranNumber][:internationalTelephone])
        end
        if phone
          @pdf_data[:data][:attributes][:identificationInformation].merge!(
            phoneNumber: { telephone: phone }
          )
        end
        if international_telephone
          if @pdf_data[:data][:attributes][:identificationInformation][:phoneNumber].present?
            @pdf_data[:data][:attributes][:identificationInformation][:phoneNumber][:internationalTelephone] =
              international_telephone
          else
            @pdf_data[:data][:attributes][:identificationInformation].merge!(
              phoneNumber: { internationalTelephone: international_telephone }
            )
          end
        end
        additional_identification_info

        @pdf_data[:data][:attributes][:identificationInformation].delete(:veteranNumber)

        mailing_address

        @pdf_data[:data][:attributes].delete(:veteranIdentification)

        @pdf_data
      end

      def mailing_address
        mailing_addr = @auto_claim&.dig('veteranIdentification', 'mailingAddress')
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:numberAndStreet] =
          concatenate_address(mailing_addr['addressLine1'], mailing_addr['addressLine2'], mailing_addr['addressLine3'])
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].delete(:addressLine1)
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].delete(:addressLine2)
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].delete(:addressLine3)

        country = @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:country]
        abbr_country = country == 'USA' ? 'US' : country
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:country] = abbr_country
        zip
      end

      def concatenate_address(address_line_one, address_line_two, address_line_three)
        concatted = "#{address_line_one || ''} #{address_line_two || ''} #{address_line_three || ''}"
        concatted.strip
      end

      def zip
        zip_first_five = (@auto_claim&.dig('veteranIdentification', 'mailingAddress', 'zipFirstFive') || '')
        zip_last_four = (@auto_claim&.dig('veteranIdentification', 'mailingAddress', 'zipLastFour') || '')
        zip = if zip_last_four.present?
                "#{zip_first_five}-#{zip_last_four}"
              else
                zip_first_five
              end
        mailing_addr = @pdf_data&.dig(:data, :attributes, :identificationInformation, :mailingAddress).present?
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].merge!(zip:) if mailing_addr
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].delete(:zipFirstFive)
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].delete(:zipLastFour)

        @pdf_data
      end

      def disability_attributes
        @pdf_data[:data][:attributes][:claimInformation] = {}
        @pdf_data[:data][:attributes][:claimInformation].merge!(
          { disabilities: [] }
        )
        conditions_related_to_exposure?

        disabilities = transform_disabilities

        details = disabilities[:data][:attributes][:claimInformation][:disabilities].map(
          &:deep_symbolize_keys
        )
        @pdf_data[:data][:attributes][:claimInformation][:disabilities] = details

        @pdf_data[:data][:attributes].delete(:disabilities)
        @pdf_data
      end

      def transform_disabilities # rubocop:disable Metrics/MethodLength
        d2 = []
        claim_disabilities = @auto_claim&.dig('disabilities')&.map do |disability|
          disability['disability'] = disability['name']
          if disability['approximateDate'].present?
            approx_date = format_date_string(disability['approximateDate'])

            disability['approximateDate'] = approx_date
          end
          disability.delete('name')
          disability.delete('classificationCode')
          disability.delete('ratedDisabilityId')
          disability.delete('diagnosticCode')
          disability.delete('disabilityActionType')
          disability.delete('isRelatedToToxicExposure')
          sec_dis = disability['secondaryDisabilities']&.map do |secondary_disability|
            secondary_disability['disability'] = secondary_disability['name']
            if secondary_disability['approximateDate'].present?
              approx_date = format_date_string(secondary_disability['approximateDate'])
              secondary_disability['approximateDate'] = approx_date
            end
            secondary_disability.delete('name')
            secondary_disability.delete('classificationCode')
            secondary_disability.delete('ratedDisabilityId')
            secondary_disability.delete('diagnosticCode')
            secondary_disability.delete('disabilityActionType')
            secondary_disability.delete('isRelatedToToxicExposure')
            secondary_disability
          end
          d2 << sec_dis
          disability.delete('secondaryDisabilities')
          disability
        end
        claim_disabilities << d2
        @pdf_data[:data][:attributes][:claimInformation][:disabilities] = claim_disabilities.flatten.compact

        @pdf_data
      end

      def conditions_related_to_exposure?
        # If any disability is included in the request with 'isRelatedToToxicExposure' set to true,
        # set exposureInformation.hasConditionsRelatedToToxicExposures to true.
        if @pdf_data[:data][:attributes][:exposureInformation].nil?
          @pdf_data[:data][:attributes][:exposureInformation] = { hasConditionsRelatedToToxicExposures: nil }
        end
        has_conditions = @auto_claim['disabilities'].any? do |disability|
          disability['isRelatedToToxicExposure'] == true
        end
        @pdf_data[:data][:attributes][:exposureInformation][:hasConditionsRelatedToToxicExposures] =
          has_conditions ? 'YES' : 'NO'
        @pdf_data[:data][:attributes][:claimInformation][:disabilities]&.map do |disability|
          disability.delete(:isRelatedToToxicExposure)
        end

        @pdf_data
      end

      def treatment_centers
        @pdf_data[:data][:attributes][:claimInformation].merge!(
          treatments: []
        )
        if @auto_claim&.dig('treatments').present?
          treatments = get_treatments

          treatment_details = treatments.map(&:deep_symbolize_keys)
          @pdf_data[:data][:attributes][:claimInformation][:treatments] = treatment_details
        end
        @pdf_data[:data][:attributes].delete(:treatments)

        @pdf_data
      end

      def get_treatments
        @auto_claim['treatments'].map do |tx|
          center = "#{tx['center']['name']}, #{tx.dig('center', 'city')}, #{tx.dig('center', 'state')}"
          name = tx['treatedDisabilityNames'].join(', ')
          tx['treatmentDetails'] = "#{name} - #{center}"
          tx['dateOfTreatment'] = regex_date_conversion(tx['beginDate']) if tx['beginDate'].present?
          tx['doNotHaveDate'] = tx['beginDate'].nil?
          tx.delete('center')
          tx.delete('treatedDisabilityNames')
          tx.delete('beginDate')
          tx
        end
      end

      def service_info
        symbolize_service_info
        most_recent_service_period
        array_of_remaining_service_date_objects
        confinements
        national_guard
        service_info_other_names
        fed_activation

        @pdf_data
      end

      def symbolize_service_info
        @pdf_data[:data][:attributes][:serviceInformation].merge!(
          @auto_claim['serviceInformation'].deep_symbolize_keys
        )
        if @auto_claim.dig('data', 'attributes', 'serviceInformation', 'servedInActiveCombatSince911').present?
          served_in_active_combat_since911 =
            @pdf_data[:data][:attributes][:serviceInformation][:servedInActiveCombatSince911]
          @pdf_data[:data][:attributes][:serviceInformation][:servedInActiveCombatSince911] =
            served_in_active_combat_since911 == true ? 'YES' : 'NO'
        end
        served_in_reserves_or_national_guard =
          @pdf_data[:data][:attributes][:serviceInformation][:servedInReservesOrNationalGuard]
        @pdf_data[:data][:attributes][:serviceInformation][:servedInReservesOrNationalGuard] =
          served_in_reserves_or_national_guard == true ? 'YES' : 'NO'

        @pdf_data
      end

      def most_recent_service_period
        @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService] = {}
        most_recent_period = get_most_recent_period
        convert_active_duty_dates(most_recent_period)
        service_component = most_recent_period[:serviceComponent]
        map_component = SERVICE_COMPONENTS[service_component]
        @pdf_data[:data][:attributes][:serviceInformation][:serviceComponent] = map_component

        @pdf_data
      end

      def get_most_recent_period
        @pdf_data[:data][:attributes][:serviceInformation][:servicePeriods].max_by do |sp|
          (sp[:activeDutyEndDate].presence || {})
        end
      end

      def convert_active_duty_dates(most_recent_period)
        if most_recent_period[:activeDutyBeginDate].present?
          @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService].merge!(
            start: regex_date_conversion(most_recent_period[:activeDutyBeginDate])
          )
        end
        if most_recent_period[:activeDutyEndDate].present?
          @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService].merge!(
            end: regex_date_conversion(most_recent_period[:activeDutyEndDate])
          )
        end
        @pdf_data[:data][:attributes][:serviceInformation][:placeOfLastOrAnticipatedSeparation] =
          most_recent_period[:separationLocationCode]
        @pdf_data[:data][:attributes][:serviceInformation].merge!(branchOfService: {
                                                                    branch: most_recent_period[:serviceBranch]
                                                                  })
        most_recent_period
      end

      def array_of_remaining_service_date_objects
        arr = []
        @pdf_data[:data][:attributes][:serviceInformation][:servicePeriods].each do |sp|
          next if sp[:activeDutyBeginDate].nil? || sp[:activeDutyEndDate].nil?

          arr.push({ start: regex_date_conversion(sp[:activeDutyBeginDate]),
                     end: regex_date_conversion(sp[:activeDutyEndDate]) })
        end
        sorted = arr&.sort_by { |sp| sp[:activeDutyEndDate] }
        sorted.pop if sorted.count > 1
        @pdf_data[:data][:attributes][:serviceInformation][:additionalPeriodsOfService] = sorted
        @pdf_data[:data][:attributes][:serviceInformation].delete(:servicePeriods)
        @pdf_data
      end

      def confinements
        return if @pdf_data[:data][:attributes][:serviceInformation][:confinements].blank?

        si = []
        @pdf_data[:data][:attributes][:serviceInformation][:prisonerOfWarConfinement] = { confinementDates: [] }
        @pdf_data[:data][:attributes][:serviceInformation][:confinements].map do |confinement|
          start_date = regex_date_conversion(confinement[:approximateBeginDate])
          end_date = regex_date_conversion(confinement[:approximateEndDate])

          si.push({
                    start: start_date, end: end_date
                  })
          si
        end
        pow = si.present?
        @pdf_data[:data][:attributes][:serviceInformation][:prisonerOfWarConfinement][:confinementDates] = si
        @pdf_data[:data][:attributes][:serviceInformation][:confinedAsPrisonerOfWar] = pow ? 'YES' : 'NO'
        @pdf_data[:data][:attributes][:serviceInformation].delete(:confinements)

        @pdf_data
      end

      def national_guard # rubocop:disable Metrics/MethodLength
        si = {}
        reserves = @pdf_data&.dig(:data, :attributes, :serviceInformation, :reservesNationalGuardService)
        si[:servedInReservesOrNationalGuard] = 'YES' if reserves
        @pdf_data[:data][:attributes][:serviceInformation].merge!(si)
        if reserves.present?
          if reserves&.dig(:obligationTermsOfService).present?
            reserves_begin_date = reserves[:obligationTermsOfService][:beginDate]
            reserves[:obligationTermsOfService][:start] = regex_date_conversion(reserves_begin_date)
            reserves[:obligationTermsOfService].delete(:beginDate)
            reserves_end_date = reserves[:obligationTermsOfService][:endDate]
            reserves[:obligationTermsOfService][:end] = regex_date_conversion(reserves_end_date)
            reserves[:obligationTermsOfService].delete(:endDate)
          end
          component = reserves[:component]
          reserves[:component] = NATIONAL_GUARD_COMPONENTS[component]

          area_code = reserves&.dig(:unitPhone, :areaCode)
          phone_number = reserves&.dig(:unitPhone, :phoneNumber)
          reserves[:unitPhoneNumber] = convert_phone(area_code + phone_number) if area_code && phone_number
          reserves.delete(:unitPhone)

          reserves[:receivingInactiveDutyTrainingPay] = handle_yes_no(reserves[:receivingInactiveDutyTrainingPay])
          @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService] = reserves
        end
      end
      # rubocop:enable Layout/LineLength

      def service_info_other_names
        other_names = @pdf_data[:data][:attributes][:serviceInformation][:alternateNames].present?
        @pdf_data[:data][:attributes][:serviceInformation][:servedUnderAnotherName] = 'YES' if other_names
      end

      def fed_activation
        return if @pdf_data.dig(:data, :attributes, :serviceInformation, :federalActivation).nil?

        ten = @pdf_data[:data][:attributes][:serviceInformation][:federalActivation]
        @pdf_data[:data][:attributes][:serviceInformation][:federalActivation] = {}
        activation_date = ten[:activationDate]
        @pdf_data[:data][:attributes][:serviceInformation][:federalActivation][:activationDate] =
          regex_date_conversion(activation_date)

        anticipated_sep_date = ten[:anticipatedSeparationDate]
        @pdf_data[:data][:attributes][:serviceInformation][:federalActivation][:anticipatedSeparationDate] =
          regex_date_conversion(anticipated_sep_date)
        @pdf_data[:data][:attributes][:serviceInformation][:activatedOnFederalOrders] = activation_date ? 'YES' : 'NO'
        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService].delete(:federalActivation)

        @pdf_data
      end

      def direct_deposit_information
        @pdf_data[:data][:attributes][:directDepositInformation] = @pdf_data[:data][:attributes][:directDeposit]
        @pdf_data[:data][:attributes].delete(:directDeposit)

        @pdf_data
      end

      def claim_date_and_signature
        first_name = @auth_headers[:va_eauth_firstName]
        last_name = @auth_headers[:va_eauth_lastName]
        name = "#{first_name} #{last_name}"
        claim_date = Date.parse(@auto_claim&.dig('claimDate').presence || Time.zone.today.to_s)
        claim_date_mdy = claim_date.strftime('%m-%d-%Y')
        @pdf_data[:data][:attributes].merge!(claimCertificationAndSignature: {
                                               dateSigned: regex_date_conversion(claim_date_mdy),
                                               signature: name
                                             })
        @pdf_data[:data][:attributes].delete(:claimDate)
      end

      def get_service_pay
        @pdf_data[:data][:attributes].merge!(
          servicePay: @auto_claim&.dig('servicePay')&.deep_symbolize_keys
        )
        service_pay = @pdf_data&.dig(:data, :attributes, :servicePay)
        handle_service_pay if service_pay.present?
        handle_military_retired_pay if service_pay&.dig(:militaryRetiredPay).present?
        handle_seperation_severance_pay if service_pay&.dig(:separationSeverancePay).present?

        @pdf_data
      end

      def handle_yes_no(pay)
        pay ? 'YES' : 'NO'
      end

      def handle_branch(branch)
        { branch: }
      end

      def handle_service_pay
        service_pay = @pdf_data&.dig(:data, :attributes, :servicePay)
        service_pay[:receivingMilitaryRetiredPay] = handle_yes_no(service_pay[:receivingMilitaryRetiredPay])
        service_pay[:futureMilitaryRetiredPay] = handle_yes_no(service_pay[:futureMilitaryRetiredPay])
        service_pay[:receivedSeparationOrSeverancePay] = handle_yes_no(service_pay[:receivedSeparationOrSeverancePay])
      end

      def handle_military_retired_pay
        military_retired_pay = @pdf_data&.dig(:data, :attributes, :servicePay, :militaryRetiredPay)
        branch_of_service = military_retired_pay[:branchOfService]
        military_retired_pay[:branchOfService] = handle_branch(branch_of_service) unless branch_of_service.nil?
      end

      def handle_seperation_severance_pay
        seperation_severance_pay = @pdf_data&.dig(:data, :attributes, :servicePay, :separationSeverancePay)
        branch_of_service = @pdf_data&.dig(:data, :attributes, :servicePay, :separationSeverancePay, :branchOfService)
        seperation_severance_pay[:branchOfService] = handle_branch(branch_of_service)
        seperation_severance_pay[:datePaymentReceived] =
          regex_date_conversion(seperation_severance_pay[:datePaymentReceived])
      end

      def convert_date_to_object(date_string)
        return '' if date_string.blank?

        date_format = DATE_FORMATS[date_string.length]
        send(date_format, date_string) if date_format
      end

      def convert_date_string_to_format_mdy(date_string)
        arr = date_string.split('-')
        {
          month: arr[0].to_s,
          day: arr[1].to_s,
          year: arr[2].to_s
        }
      end

      def convert_date_string_to_format_my(date_string)
        arr = date_string.split('-')
        {
          month: arr[0].to_s,
          year: arr[1].to_s
        }
      end

      def convert_phone(phone)
        phone&.gsub!(/[^0-9]/, '')
        return nil if phone.nil? || (phone.length < 10)

        return "#{phone[0..2]}-#{phone[3..5]}-#{phone[6..9]}" if phone.length == 10

        "#{phone[0..1]}-#{phone[2..3]}-#{phone[4..7]}-#{phone[8..11]}" if phone.length > 10
      end

      def convert_date_string_to_format_yyyy(date_string)
        date = Date.strptime(date_string, '%Y')
        {
          year: date.year
        }
      end

      def format_date_string(date_string)
        if date_string.length == 4
          Date.strptime(date_string, '%Y').strftime('%Y')
        elsif date_string.length == 7
          Date.strptime(date_string, '%Y-%m').strftime('%B %Y')
        else
          Date.strptime(date_string, '%Y-%m-%d').strftime('%B %Y')
        end
      end

      def additional_identification_info
        name = {
          lastName: @auth_headers[:va_eauth_lastName],
          firstName: @auth_headers[:va_eauth_firstName],
          middleInitial: @middle_initial
        }
        birth_date_data = @auth_headers[:va_eauth_birthdate]
        if birth_date_data
          birth_date =
            {
              month: birth_date_data[5..6].to_s,
              day: birth_date_data[8..9].to_s,
              year: birth_date_data[0..3].to_s
            }
        end
        ssn = @auth_headers[:va_eauth_pnid]
        formated_ssn = "#{ssn[0..2]}-#{ssn[3..4]}-#{ssn[5..8]}"
        @pdf_data[:data][:attributes][:identificationInformation][:name] = name
        @pdf_data[:data][:attributes][:identificationInformation][:ssn] = formated_ssn
        @pdf_data[:data][:attributes][:identificationInformation][:dateOfBirth] = birth_date
        @pdf_data
      end

      def regex_date_conversion(date)
        if date.present?
          res = date.match(/^(?:(?<year>\d{4})(?:-(?<month>\d{2}))?(?:-(?<day>\d{2}))*|(?<month>\d{2})?(?:-(?<day>\d{2}))?-?(?<year>\d{4}))$/) # rubocop:disable Layout/LineLength

          make_date_object(res, date.length)
        end
      end

      def make_date_object(date, date_length)
        if date.present? && date_length == 4
          { year: date[:year] }
        elsif date.present? && date_length == 7
          { month: date[:month], year: date[:year] }
        elsif date.present?
          { year: date[:year], month: date[:month], day: date[:day] }
        end
      end
    end
  end
end
