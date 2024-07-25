# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rails_helper'

RSpec.describe 'Evidence Waiver 5103', type: :request do
  let(:veteran_id) { '1012667145V762142' }
  let(:sponsor_id) { '1012861229V078999' }
  let(:claim_id) { '600131328' }
  let(:sub_path) { "/services/claims/v2/veterans/#{veteran_id}/claims/#{claim_id}/5103" }
  let(:error_sub_path) { "/services/claims/v2/veterans/#{veteran_id}/claims/abc123/5103" }
  let(:scopes) { %w[claim.write claim.read] }
  let(:ews) { build(:claims_api_evidence_waiver_submission) }
  let(:payload) do
    { 'ver' => 1,
      'cid' => '0oa8r55rjdDAH5Vaj2p7',
      'scp' => ['system/claim.write', 'system/claim.read'],
      'sub' => '0oa8r55rjdDAH5Vaj2p7' }
  end

  let(:target_veteran) do
    OpenStruct.new(
      icn: '1012667145V762142',
      first_name: 'Tamara',
      last_name: 'Ellis',
      loa: { current: 3, highest: 3 },
      edipi: '1007697216',
      ssn: '796130115',
      participant_id: '600043201',
      mpi: OpenStruct.new(
        icn: '1012667145V762142',
        profile: OpenStruct.new(ssn: '796130115')
      )
    )
  end

  before do
    allow_any_instance_of(ClaimsApi::V2::ApplicationController)
      .to receive(:target_veteran).and_return(target_veteran)
  end

  describe '5103 Waiver' do
    describe 'submit' do
      context 'Vet flow' do
        context 'when provided' do
          context 'when valid' do
            context 'when success' do
              it 'returns a 202' do
                mock_ccg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/benefit_claim/update_5103_200') do
                    allow_any_instance_of(ClaimsApi::LocalBGS)
                      .to receive(:find_by_ssn).and_return({ file_nbr: '123456780' })

                    post sub_path, headers: auth_header

                    expect(response.status).to eq(202)
                  end
                end
              end
            end
          end

          context 'when not valid' do
            it 'returns a 401' do
              post sub_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(401)
            end
          end

          context 'when claim id is not found' do
            it 'returns a 404' do
              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/benefit_claim/find_bnft_claim_400') do
                  allow_any_instance_of(ClaimsApi::LocalBGS)
                    .to receive(:find_by_ssn).and_return({ file_nbr: '123456780' })

                  post error_sub_path, headers: auth_header

                  expect(response.status).to eq(404)
                end
              end
            end
          end

          context 'when the submit is from a dependent' do
            it 'returns a 200 when the target_veteran.participant_id matches the pctpnt_clmant_id' do
              bgs_claim_response = build(:bgs_response_with_one_lc_status).to_h
              bgs_claim_response[:benefit_claim_details_dto][:ptcpnt_vet_id] = '867530910'
              bgs_claim_response[:benefit_claim_details_dto][:ptcpnt_clmant_id] = target_veteran[:participant_id]

              expect_any_instance_of(ClaimsApi::LocalBGS)
                .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)

              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/benefit_claim/update_5103_200') do
                  allow_any_instance_of(ClaimsApi::LocalBGS)
                    .to receive(:find_by_ssn).and_return({ file_nbr: '123456780' })

                  post sub_path, headers: auth_header

                  expect(response.status).to eq(202)
                end
              end
            end

            it 'returns a 401 when the target_veteran.participant_id does not match the pctpnt_clmant_id' do
              bgs_claim_response = build(:bgs_response_with_one_lc_status).to_h
              bgs_claim_response[:benefit_claim_details_dto][:ptcpnt_vet_id] = '867530910'
              bgs_claim_response[:benefit_claim_details_dto][:ptcpnt_clmant_id] = '867530910'

              expect_any_instance_of(ClaimsApi::LocalBGS)
                .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)

              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/benefit_claim/update_5103_200') do
                  allow_any_instance_of(ClaimsApi::LocalBGS)
                    .to receive(:find_by_ssn).and_return({ file_nbr: '123456780' })

                  post sub_path, headers: auth_header

                  expect(response.status).to eq(401)
                  json = JSON.parse(response.body)
                  expect_res = json['errors'][0]['detail']

                  expect(expect_res).to eq('Claim does not belong to this veteran')
                end
              end
            end
          end

          describe 'with missing first and last name' do
            let(:no_first_last_name_target_veteran) do
              OpenStruct.new(
                icn: '1012832025V743496',
                first_name: '',
                last_name: '',
                birth_date: '19630211',
                loa: { current: 3, highest: 3 },
                edipi: nil,
                ssn: '796043735',
                participant_id: '600061742',
                mpi: OpenStruct.new(
                  icn: '1012832025V743496',
                  profile: OpenStruct.new(ssn: '796043735')
                )
              )
            end

            context 'when a veteran does not have first and last name' do
              it 'returns an error message' do
                bgs_claim_response = build(:bgs_response_with_one_lc_status).to_h
                details = bgs_claim_response[:benefit_claim_details_dto]
                details[:ptcpnt_vet_id] = no_first_last_name_target_veteran[:participant_id]
                details[:ptcpnt_clmant_id] = target_veteran[:participant_id]

                expect_any_instance_of(ClaimsApi::LocalBGS)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                mock_ccg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/benefit_claim/update_5103_200') do
                    allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                      .to receive(:target_veteran).and_return(no_first_last_name_target_veteran)

                    post sub_path, headers: auth_header
                    json = JSON.parse(response.body)
                    expect_res = json['errors'][0]['detail']

                    expect(expect_res).to eq('Must have either first or last name')
                  end
                end
              end
            end
          end

          describe 'with missing first name' do
            let(:no_first_name_target_veteran) do
              OpenStruct.new(
                icn: '1012832025V743496',
                first_name: '',
                last_name: 'Wesley',
                birth_date: '19630211',
                loa: { current: 3, highest: 3 },
                edipi: nil,
                ssn: '796043735',
                participant_id: '600061742',
                mpi: OpenStruct.new(
                  icn: '1012832025V743496',
                  profile: OpenStruct.new(ssn: '796043735')
                )
              )
            end

            context 'when a veteran does not have first name' do
              it 'returns an accepted message' do
                bgs_claim_response = build(:bgs_response_with_one_lc_status).to_h
                details = bgs_claim_response[:benefit_claim_details_dto]
                details[:ptcpnt_vet_id] = no_first_name_target_veteran[:participant_id]
                details[:ptcpnt_clmant_id] = target_veteran[:participant_id]

                expect_any_instance_of(ClaimsApi::LocalBGS)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                mock_ccg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/benefit_claim/update_5103_200') do
                    allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                      .to receive(:target_veteran).and_return(no_first_name_target_veteran)

                    post sub_path, headers: auth_header
                    expect(response).to have_http_status(:accepted)
                  end
                end
              end
            end
          end

          context 'scopes' do
            let(:invalid_scopes) { %w[system/526-pdf.override] }
            let(:ews_scopes) { %w[system/claim.write] }

            context 'evidence waiver' do
              it 'returns a 200 response when successful' do
                mock_ccg_for_fine_grained_scope(ews_scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/benefit_claim/update_5103_200') do
                    allow_any_instance_of(ClaimsApi::LocalBGS)
                      .to receive(:find_by_ssn).and_return({ file_nbr: '123456780' })

                    post sub_path, headers: auth_header

                    expect(response).to have_http_status(:accepted)
                  end
                end
              end

              it 'returns a 401 unauthorized with incorrect scopes' do
                mock_ccg_for_fine_grained_scope(invalid_scopes) do |auth_header|
                  post sub_path, headers: auth_header
                  expect(response).to have_http_status(:unauthorized)
                end
              end
            end
          end
        end
      end
    end
  end
end
