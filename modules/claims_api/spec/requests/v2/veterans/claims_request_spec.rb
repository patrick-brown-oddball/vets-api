# frozen_string_literal: true

require 'rails_helper'
require 'token_validation/v2/client'

RSpec.describe 'Claims', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:claim_id) { '600131328' }
  let(:all_claims_path) { "/services/claims/v2/veterans/#{veteran_id}/claims" }
  let(:claim_by_id_path) { "/services/claims/v2/veterans/#{veteran_id}/claims/#{claim_id}" }
  let(:scopes) { %w[claim.read] }
  let(:profile) do
    MPI::Responses::FindProfileResponse.new(
      {
        status: 'OK',
        profile: FactoryBot.build(:mvi_profile,
                                  participant_id: nil,
                                  participant_ids: [])
      }
    )
  end

  describe 'Claims' do
    describe 'index' do
      context 'auth header' do
        context 'when provided' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(
                  benefit_claims_dto: {
                    benefit_claim: []
                  }
                )
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return([])

              get all_claims_path, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end

        context 'when not provided' do
          it 'returns a 401 error code' do
            with_okta_user(scopes) do
              get all_claims_path
              expect(response.status).to eq(401)
            end
          end
        end
      end

      context 'CCG (Client Credentials Grant) flow' do
        let(:ccg_token) { OpenStruct.new(client_credentials_token?: true, payload: { 'scp' => [] }) }

        context 'when provided' do
          context 'when valid' do
            it 'returns a 200' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(true)
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(
                  benefit_claims_dto: {
                    benefit_claim: []
                  }
                )
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return([])

              get all_claims_path, headers: { 'Authorization' => 'Bearer HelloWorld' }
              expect(response.status).to eq(200)
            end
          end

          context 'when not valid' do
            it 'returns a 403' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(false)

              get all_claims_path, headers: { 'Authorization' => 'Bearer HelloWorld' }
              expect(response.status).to eq(403)
            end
          end
        end
      end

      context 'forbidden access' do
        context 'when current user is not the target veteran' do
          context 'when current user is not a representative of the target veteran' do
            it 'returns a 403' do
              with_okta_user(scopes) do |auth_header|
                expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                  .to receive(:user_is_target_veteran?).and_return(false)
                expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                  .to receive(:user_represents_veteran?).and_return(false)

                get all_claims_path, headers: auth_header
                expect(response.status).to eq(403)
              end
            end
          end
        end
      end

      context 'veteran_id param' do
        context 'when not provided' do
          let(:veteran_id) { nil }

          it 'returns a 404 error code' do
            with_okta_user(scopes) do |auth_header|
              get all_claims_path, headers: auth_header
              expect(response.status).to eq(404)
            end
          end
        end

        context 'when known veteran_id is provided' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(
                  benefit_claims_dto: {
                    benefit_claim: []
                  }
                )
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return([])

              get all_claims_path, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end

        context 'when unknown veteran_id is provided' do
          let(:veteran) { OpenStruct.new(mpi: nil, participant_id: nil) }

          it 'returns a 403 error code' do
            with_okta_user(scopes) do |auth_header|
              expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)

              get all_claims_path, headers: auth_header
              expect(response.status).to eq(403)
            end
          end
        end
      end

      describe 'BGS attributes' do
        let(:bgs_claims) do
          {
            benefit_claims_dto: {
              benefit_claim: [
                {
                  benefit_claim_id: '600098193',
                  claim_status: 'Pending',
                  claim_status_type: 'Compensation',
                  phase_chngd_dt: 'Wed, 18 Oct 2017',
                  phase_type: 'Complete',
                  ptcpnt_clmant_id: veteran_id,
                  ptcpnt_vet_id: veteran_id,
                  phase_type_change_ind: '76'
                }
              ]
            }
          }
        end

        it 'are listed' do
          lighthouse_claim = build(:auto_established_claim, status: 'PEND', veteran_icn: veteran_id,
                                                            evss_id: '600098193')
          lighthouse_claim_two = build(:auto_established_claim, status: 'CAN', veteran_icn: veteran_id,
                                                                evss_id: '600098194')
          lh_claims = []
          lh_claims << lighthouse_claim
          lh_claims << lighthouse_claim_two

          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return(lh_claims)

              get all_claims_path, headers: auth_header

              json_response = JSON.parse(response.body)
              expect(response.status).to eq(200)
              claim = json_response['data'].first
              claim_two = json_response['data'][1]
              expect(claim['attributes']['status']).to eq('COMPLETE')
              expect(claim_two['attributes']['status']).to eq('CANCELLED')
              expect(claim['attributes']['claimPhaseDates']['phaseChangeDate']).to eq('2017-10-18')
            end
          end
        end
      end

      describe 'mapping of claims' do
        describe "handling 'lighthouseId' and 'claimId'" do
          context 'when BGS and Lighthouse claims exist' do
            let(:bgs_claims) do
              {
                benefit_claims_dto: {
                  benefit_claim: [
                    {
                      benefit_claim_id: '111111111',
                      claim_status: 'Preparation for notification'
                    }
                  ]
                }
              }
            end
            let(:lighthouse_claims) do
              [
                OpenStruct.new(
                  id: '0958d973-36fb-43ef-8801-2718bd33c825',
                  evss_id: '111111111',
                  status: 'Preparation for notification'
                )
              ]
            end

            it "provides values for 'lighthouseId' and 'claimId' " do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:where).and_return(lighthouse_claims)

                  get all_claims_path, headers: auth_header

                  json_response = JSON.parse(response.body)

                  expect(response.status).to eq(200)
                  expect(json_response['data']).to be_an_instance_of(Array)
                  expect(json_response.count).to eq(1)
                  claim = json_response['data'].first
                  expect(claim['attributes']['status']).to eq('PREPARATION_FOR_NOTIFICATION')
                  expect(claim['id']).to eq('111111111')
                  expect(claim['attributes']['lighthouseId']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                end
              end
            end
          end

          context 'when only a BGS claim exists' do
            let(:bgs_claims) do
              {
                benefit_claims_dto: {
                  benefit_claim: [
                    {
                      benefit_claim_id: '111111111',
                      phase_type: 'claim received'
                    }
                  ]
                }
              }
            end
            let(:lighthouse_claims) { [] }

            it "provides a value for 'claimId', but 'lighthouseId' will be 'nil' " do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:where).and_return(lighthouse_claims)

                  get all_claims_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response.status).to eq(200)
                  expect(json_response['data']).to be_an_instance_of(Array)
                  expect(json_response.count).to eq(1)
                  claim = json_response['data'].first
                  expect(claim['attributes']['status']).to eq('CLAIM_RECEIVED')
                  expect(claim['id']).to eq('111111111')
                  expect(claim['attributes']['lighthouseId']).to be nil
                end
              end
            end
          end

          context 'when only a Lighthouse claim exists' do
            let(:bgs_claims) do
              {
                benefit_claims_dto: {
                  benefit_claim: []
                }
              }
            end
            let(:lighthouse_claims) do
              [
                OpenStruct.new(
                  id: '0958d973-36fb-43ef-8801-2718bd33c825',
                  evss_id: '111111111',
                  status: 'pend'
                )
              ]
            end

            it "provides a value for 'lighthouseId', but 'claimId' will be 'nil' " do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:where).and_return(lighthouse_claims)

                  get all_claims_path, headers: auth_header

                  json_response = JSON.parse(response.body)

                  expect(response.status).to eq(200)
                  expect(json_response['data']).to be_an_instance_of(Array)
                  expect(json_response.count).to eq(1)
                  claim = json_response['data'].first
                  expect(claim['attributes']['status']).to eq('PENDING')
                  expect(claim['attributes']['lighthouseId']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                  expect(claim['id']).to be nil
                end
              end
            end
          end

          context 'when no claims exist' do
            let(:bgs_claims) do
              {
                benefit_claims_dto: {
                  benefit_claim: []
                }
              }
            end
            let(:lighthouse_claims) { [] }

            it 'returns an empty collection' do
              with_okta_user(scopes) do |auth_header|
                expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                  .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:where).and_return(lighthouse_claims)

                get all_claims_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(200)
                expect(json_response['data']).to be_an_instance_of(Array)
                expect(json_response['data'].count).to eq(0)
              end
            end
          end
        end
      end

      describe 'participant ID' do
        context 'when missing' do
          let(:ccg_token) { OpenStruct.new(client_credentials_token?: true, payload: { 'scp' => [] }) }

          it 'returns a 422' do
            allow(JWT).to receive(:decode).and_return(nil)
            allow(Token).to receive(:new).and_return(ccg_token)
            allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(true)

            allow_any_instance_of(MPIData)
              .to receive(:mvi_response).and_return(profile)

            get all_claims_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

            expect(response.status).to eq(422)
            json_response = JSON.parse(response.body)
            expect(json_response['errors'][0]['detail']).to eq(
              "Unable to locate Veteran's Participant ID in Master Person Index (MPI). " \
              'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
            )
          end
        end
      end
    end

    describe 'show with validate_id_with_icn' do
      let(:bgs_claim_response) { build(:bgs_response_with_one_lc_status).to_h }

      describe ' BGS attributes' do
        it 'are listed' do
          lh_claim = create(:auto_established_claim, status: 'PENDING', veteran_icn: veteran_id,
                                                     evss_id: '111111111')
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
              VCR.use_cassette('evss/documents/get_claim_documents') do
                bgs_claim_response[:benefit_claim_details_dto][:ptcpnt_vet_id] = '600061742'
                expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:get_by_id_and_icn).and_return(lh_claim)

                get claim_by_id_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(200)
                expect(json_response['data']['attributes']['claimPhaseDates']['currentPhaseBack']).to eq(true)
                expect(json_response['data']['attributes']['claimPhaseDates']['latestPhaseType'])
                  .to eq('Claim Received')
                expect(json_response['data']['attributes']['claimPhaseDates']['previousPhases']).to be_truthy
              end
            end
          end
        end
      end
    end

    describe 'show' do
      let(:bgs_claim_response) { build(:bgs_response_with_one_lc_status).to_h }

      before do
        allow_any_instance_of(ClaimsApi::V2::Veterans::ClaimsController)
          .to receive(:validate_id_with_icn).and_return(nil)
      end

      describe ' BGS attributes' do
        it 'are listed' do
          lh_claim = create(:auto_established_claim, status: 'PENDING', veteran_icn: veteran_id,
                                                     evss_id: '111111111')
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
              VCR.use_cassette('evss/documents/get_claim_documents') do
                expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:get_by_id_and_icn).and_return(lh_claim)

                get claim_by_id_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(200)
                claim_attributes = json_response['data']['attributes']
                expect(claim_attributes['claimPhaseDates']['currentPhaseBack']).to eq(true)
                expect(claim_attributes['claimPhaseDates']['latestPhaseType']).to eq('Claim Received')
                expect(claim_attributes['claimPhaseDates']['previousPhases']).to be_truthy
              end
            end
          end
        end
      end

      context 'when no auth header provided' do
        it 'returns a 401 error code' do
          with_okta_user(scopes) do
            get claim_by_id_path
            expect(response.status).to eq(401)
          end
        end
      end

      context 'when current user is not the target veteran' do
        context 'when current user is not a representative of the target veteran' do
          it 'returns a 403' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_is_target_veteran?).and_return(false)
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_represents_veteran?).and_return(false)

              get claim_by_id_path, headers: auth_header
              expect(response.status).to eq(403)
            end
          end
        end
      end

      context 'when looking for a Lighthouse claim' do
        let(:claim_id) { '123-abc-456-def' }

        context 'when a Lighthouse claim does not exist' do
          it 'returns a 404' do
            with_okta_user(scopes) do |auth_header|
              expect(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_and_icn).and_return(nil)

              get claim_by_id_path, headers: auth_header

              expect(response.status).to eq(404)
            end
          end
        end

        context 'when a Lighthouse claim does exist' do
          let(:lighthouse_claim) do
            create(:auto_established_claim, status: 'PENDING', veteran_icn: '1013062086V794840',
                                            evss_id: '111111111')
          end
          let(:matched_claim_veteran_path) do
            "/services/claims/v2/veterans/#{lighthouse_claim.veteran_icn}/claims/#{lighthouse_claim.id}"
          end

          context 'and is not associated with the current user' do
            let(:not_vet_lh_claim) do
              create(:auto_established_claim, status: 'PENDING', veteran_icn: '456')
            end
            let(:mismatched_claim_veteran_path) do
              "/services/claims/v2/veterans/#{lighthouse_claim.veteran_icn}/claims/#{not_vet_lh_claim.id}"
            end

            it 'returns a 404' do
              with_okta_user(scopes) do |auth_header|
                get mismatched_claim_veteran_path, headers: auth_header

                expect(response.status).to eq(404)
              end
            end
          end

          context 'and is associated with the current user' do
            let(:bgs_claim) { nil }

            it 'returns a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                  get matched_claim_veteran_path, headers: auth_header

                  expect(response.status).to eq(200)
                end
              end
            end
          end

          context 'and a BGS claim does not exist' do
            let(:bgs_claim) { nil }

            describe "handling 'lighthouseId' and 'claimId'" do
              it "provides a value for 'lighthouseId', but 'claimId' will be 'nil' " do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                    expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                      .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                    get matched_claim_veteran_path, headers: auth_header

                    json_response = JSON.parse(response.body)
                    expect(response.status).to eq(200)
                    expect(json_response).to be_an_instance_of(Hash)
                    expect(json_response['data']['attributes']['status']).to eq('PENDING')
                    expect(json_response['data']['id']).to be nil
                  end
                end
              end
            end
          end

          context 'and a BGS claim does exist' do
            let(:bgs_claim) { build(:bgs_response_with_one_lc_status) }

            describe "handling 'lighthouseId' and 'claimId'" do
              it "provides a value for 'lighthouseId' and 'claimId'" do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                    VCR.use_cassette('evss/documents/get_claim_documents') do
                      expect(ClaimsApi::AutoEstablishedClaim)
                        .to receive(:get_by_id_and_icn).and_return(lighthouse_claim)
                      expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                        .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                      get matched_claim_veteran_path, headers: auth_header

                      json_response = JSON.parse(response.body)
                      expect(response.status).to eq(200)
                      expect(json_response).to be_an_instance_of(Hash)
                      expect(json_response['data']['attributes']['lighthouseId']).to eq(lighthouse_claim.id)
                      expect(json_response['data']['id']).to eq('111111111')
                    end
                  end
                end
              end
            end
          end
        end
      end

      context 'when looking for a BGS claim' do
        let(:claim_id) { '123456789' }

        context 'when a BGS claim does not exist' do
          it 'returns a 404' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(nil)

              get claim_by_id_path, headers: auth_header

              expect(response.status).to eq(404)
            end
          end
        end

        context 'when a BGS claim does exist' do
          let(:bgs_claim) { build(:bgs_response_with_one_lc_status).to_h }

          context 'and a Lighthouse claim exists' do
            let(:lighthouse_claim) do
              OpenStruct.new(
                id: '0958d973-36fb-43ef-8801-2718bd33c825',
                evss_id: '111111111',
                status: 'pending'
              )
            end

            describe "handling 'lighthouseId' and 'claimId'" do
              it "provides a value for 'lighthouseId' and 'claimId'" do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                    VCR.use_cassette('evss/documents/get_claim_documents') do
                      expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                        .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                      expect(ClaimsApi::AutoEstablishedClaim)
                        .to receive(:get_by_id_and_icn).and_return(lighthouse_claim)

                      get claim_by_id_path, headers: auth_header

                      json_response = JSON.parse(response.body)
                      expect(response.status).to eq(200)
                      claim_attributes = json_response['data']['attributes']
                      expect(json_response).to be_an_instance_of(Hash)
                      expect(claim_attributes['lighthouseId']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                      expect(json_response['data']['id']).to eq('111111111')
                    end
                  end
                end
              end
            end
          end

          context 'and a Lighthouse claim does not exit' do
            it "provides a value for 'claimId', but 'lighthouseId' will be 'nil' " do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                  VCR.use_cassette('evss/documents/get_claim_documents') do
                    expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                      .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                    expect(ClaimsApi::AutoEstablishedClaim)
                      .to receive(:get_by_id_and_icn).and_return(nil)

                    get claim_by_id_path, headers: auth_header

                    json_response = JSON.parse(response.body)
                    expect(response.status).to eq(200)
                    expect(json_response).to be_an_instance_of(Hash)
                    expect(json_response['data']['id']).to eq('111111111')
                    expect(json_response['data']['attributes']['lighthouseId']).to be nil
                  end
                end
              end
            end
          end
        end
      end

      describe "handling the 'status'" do
        context 'when there is 1 status' do
          it "sets the 'status'" do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('evss/documents/get_claim_documents') do
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response.status).to eq(200)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['status']).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
                end
              end
            end
          end
        end

        context 'when the claim is complete' do
          let(:bgs_claim) { build(:bgs_response_with_lc_status).to_h }

          it 'shows a closed date' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('evss/documents/get_claim_documents') do
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  d = Date.parse(bgs_claim[:benefit_claim_details_dto][:claim_complete_dt].to_s)
                  expected_date = d.strftime('%Y-%m-%d')
                  json_response = JSON.parse(response.body)
                  expect(response.status).to eq(200)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['closeDate']).to eq(expected_date)
                end
              end
            end
          end
        end

        context 'when a typical status is received' do
          it "the v2 mapper sets the correct 'status'" do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('evss/documents/get_claim_documents') do
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response.status).to eq(200)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['status']).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
                end
              end
            end
          end
        end

        context 'when a grouped status is received' do
          let(:bgs_claim) do
            {
              benefit_claim_details_dto: {
                benefit_claim_id: '111111111',
                claim_status_type: 'value from BGS',
                bnft_claim_lc_status: {
                  phase_type: 'Pending Decision Approval'
                }
              }
            }
          end

          it "the v2 mapper sets the 'status' correctly" do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('evss/documents/get_claim_documents') do
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response.status).to eq(200)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['status']).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
                end
              end
            end
          end
        end

        context 'when an Under Review status is received' do
          let(:bgs_claim) { build(:bgs_response_with_under_review_lc_status).to_h }

          it "the v2 mapper sets the 'status' correctly" do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('evss/documents/get_claim_documents') do
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response.status).to eq(200)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['status']).to eq('INITIAL_REVIEW')
                end
              end
            end
          end
        end

        context 'it picks the newest status' do
          it "returns a claim with the 'claimId' and 'lighthouseId' set" do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('evss/documents/get_claim_documents') do
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response.status).to eq(200)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['claimType']).to eq('Compensation')
                  expect(json_response['data']['attributes']['status']).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
                end
              end
            end
          end
        end
      end

      describe "handling the 'supporting_documents'" do
        context 'it has documents' do
          it "returns a claim with 'supporting_documents'" do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('evss/documents/get_claim_documents') do
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  first_doc_id = json_response['data']['attributes'].dig('supportingDocuments', 0, 'documentId')
                  expect(response.status).to eq(200)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['claimType']).to eq('Compensation')
                  expect(first_doc_id).to eq('{54EF0C16-A9E7-4C3F-B876-B2C7BEC1F834}')
                end
              end
            end
          end
        end

        context 'it has no documents' do
          let(:bgs_claim) { build(:bgs_response_with_one_lc_status).to_h }

          it "returns a claim with 'suporting_documents' as an empty array" do
            bgs_claim[:benefit_claim_details_dto][:benefit_claim_id] = '222222222'

            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('evss/documents/get_claim_documents') do
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response.status).to eq(200)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['claimType']).to eq('Compensation')
                  expect(json_response['data']['attributes']['supportingDocuments']).to be_empty
                end
              end
            end
          end
        end

        context 'it has no bgs_claim' do
          let(:lighthouse_claim) do
            create(:auto_established_claim, status: 'PENDING', veteran_icn: '1013062086V794840',
                                            evss_id: '111111111')
          end
          let(:matched_claim_veteran_path) do
            "/services/claims/v2/veterans/#{lighthouse_claim.veteran_icn}/claims/#{lighthouse_claim.id}"
          end
          let(:bgs_claim) { nil }

          it "returns a claim with 'suporting_documents' as an empty array" do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                get matched_claim_veteran_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(200)
                expect(json_response).to be_an_instance_of(Hash)
                expect(json_response['data']['attributes']['supportingDocuments']).to be_empty
              end
            end
          end
        end

        context 'it has an errors array' do
          let(:claim) do
            create(
              :auto_established_claim_with_supporting_documents,
              :status_errored,
              source: 'abraham lincoln',
              veteran_icn: veteran_id,
              evss_response: [
                {
                  severity: 'ERROR',
                  detail: 'Something happened',
                  key: 'test.path.here'
                }
              ]
            )
          end
          let(:claim_by_id_path) { "/services/claims/v2/veterans/#{claim.veteran_icn}/claims/#{claim.id}" }

          it "returns a claim with the 'errors' attribute populated" do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                get claim_by_id_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(200)
                expect(json_response['data']['attributes'].dig('errors', 0, 'detail')).to eq('ERROR Something happened')
                expect(json_response['data']['attributes'].dig('errors', 0, 'source')).to eq('test/path/here')
                expect(json_response['data']['attributes']['status']).to eq('ERRORED')
              end
            end
          end
        end
      end

      describe "handling the 'tracked_items'" do
        context 'it has tracked items' do
          let(:claim_id_with_items) { '600236068' }
          let(:claim_by_id_with_items_path) do
            "/services/claims/v2/veterans/#{veteran_id}/claims/#{claim_id_with_items}"
          end

          it "returns a claim with 'tracked_items'" do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette(
                'bgs/ebenefits_benefit_claims_status/find_benefit_claim_details_by_benefit_claim_id'
              ) do
                VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                  VCR.use_cassette('evss/documents/get_claim_documents') do
                    expect(ClaimsApi::AutoEstablishedClaim)
                      .to receive(:get_by_id_and_icn).and_return(nil)

                    get claim_by_id_with_items_path, headers: auth_header

                    json_response = JSON.parse(response.body)
                    first_doc_id = json_response['data']['attributes'].dig('trackedItems', 0, 'trackedItemId')
                    expect(response.status).to eq(200)
                    expect(json_response).to be_an_instance_of(Hash)
                    expect(json_response['data']['id']).to eq('600236068')
                    expect(first_doc_id).to eq(325_525)
                  end
                end
              end
            end
          end
        end

        context 'it has no bgs_claim' do
          let(:lighthouse_claim) do
            create(:auto_established_claim, status: 'PENDING', veteran_icn: '1013062086V794840',
                                            evss_id: '111111111')
          end
          let(:matched_claim_veteran_path) do
            "/services/claims/v2/veterans/#{lighthouse_claim.veteran_icn}/claims/#{lighthouse_claim.id}"
          end
          let(:bgs_claim) { nil }

          it "returns a claim with 'tracked_items' as an empty array" do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                get matched_claim_veteran_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(200)
                expect(json_response).to be_an_instance_of(Hash)
                expect(json_response['data']['attributes']['trackedItems']).to be_empty
              end
            end
          end
        end
      end

      context 'CCG (Client Credentials Grant)' do
        let(:claim_id) { '123-abc-456-def' }
        let(:lighthouse_claim) do
          OpenStruct.new(
            id: '0958d973-36fb-43ef-8801-2718bd33c825',
            evss_id: '111111111',
            claim_type: 'Compensation',
            status: 'pending'
          )
        end

        context 'when provided' do
          context 'when valid' do
            it 'returns a 200' do
              VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                allow(JWT).to receive(:decode).and_return(nil)
                allow(Token).to receive(:new).and_return(
                  OpenStruct.new(
                    client_credentials_token?: true,
                    payload: { 'scp' => [] }
                  )
                )
                allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(true)
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:get_by_id_and_icn).and_return(lighthouse_claim)
                expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(nil)

                get claim_by_id_path, headers: { 'Authorization' => 'Bearer HelloWorld' }
                expect(response.status).to eq(200)
              end
            end
          end

          context 'when not valid' do
            it 'returns a 403' do
              VCR.use_cassette('bgs/tracked_items/find_tracked_items') do
                allow(JWT).to receive(:decode).and_return(nil)
                allow(Token).to receive(:new).and_return(
                  OpenStruct.new(
                    client_credentials_token?: true,
                    payload: { 'scp' => [] }
                  )
                )
                allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(false)

                get claim_by_id_path, headers: { 'Authorization' => 'Bearer HelloWorld' }
                expect(response.status).to eq(403)
              end
            end
          end
        end
      end
    end
  end
end
