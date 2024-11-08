# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

module Vye
  module V1
    RSpec.describe DgibVerificationsController, type: :controller do
      let!(:current_user) { create(:user, :accountable) }
      let(:claimant_id) { '1' }

      before do
        # Nothing with the routing seemed to work but subject.claimant_lookup works. However
        # it gives this error:
        # Module::DelegationError:
        #  ActionController::Metal#media_type delegated to @_response.media_type, but @_response is nil: 
        # #<Vye::V1::DgibVerificationsController:0x0000000003b150>
        # What makes this work is to set the @_response instance variable.
        subject.instance_variable_set(:@_response, ActionDispatch::Response.new)

        sign_in_as(current_user)
        allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
      end

      describe '#claimant_lookup' do
        let(:claimant_service_response) { create_claimant_response }
        let(:serializer) { Vye::ClaimantLookupSerializer.new(claimant_service_response) }

        before do
          allow_any_instance_of(Vye::UserInfoPolicy).to receive(:claimant_lookup?).and_return(true)
          allow_any_instance_of(Vye::DGIB::ClaimantLookup::Service)
            .to receive(:claimant_lookup)
            .and_return(claimant_service_response)

          allow(Vye::ClaimantLookupSerializer)
            .to receive(:new)
            .with(claimant_service_response)
            .and_return(serializer)
        end

        context 'when the service returns a successful response' do
          it 'calls the claimant_lookup_service' do
            expect_any_instance_of(Vye::DGIB::ClaimantLookup::Service)
              .to receive(:claimant_lookup).with(current_user.ssn)

            # You have to do this or the test will fail.
            # Something buried in pundit is preventing it from working without it
            # Consequently, no separate test for pundit
            expect(controller).to receive(:authorize).with(@current_user, policy_class: UserInfoPolicy).and_return(true)

            subject.claimant_lookup
          end

          it 'renders the serialized response with a 200 status' do
            # You have to do this or the test will fail.
            # Something buried in pundit is preventing it from working without it
            # Consequently, no separate test for pundit
            expect(controller).to receive(:authorize).with(@current_user, policy_class: UserInfoPolicy).and_return(true)

            # Chatgpt says do this, but it does not work:
            # expect(controller).to receive(:render).with(json: serializer.new(claimant_service_response).to_json)
            # What works is this
            expect(controller).to receive(:render).with(json: serializer.serializable_hash.to_json)

            subject.claimant_lookup
          end
        end
      end

      def create_claimant_response
        response_struct = Struct.new(:body)
        response = response_struct.new({ 'claimant_id' => 1 })
        Vye::DGIB::ClaimantLookup::Response.new(200, response)
      end

      describe '#verify_claimant' do
        let(:verify_claimant_response) { create_verify_claimant_response }
        let(:serializer) { Vye::VerifyClaimantSerializer.new(verify_claimant_response) }
        let(:verified_period_begin_date) { '2024-11-01' }
        let(:verified_period_end_date) { '2024-11-30' }
        let(:verfied_through_date) { '2023-11-30' }

        before do
          allow_any_instance_of(Vye::UserInfoPolicy).to receive(:verify_claimant?).and_return(true)
          allow_any_instance_of(Vye::DGIB::VerifyClaimant::Service)
            .to receive(:verify_claimant)
            .and_return(verify_claimant_response)

          allow(Vye::VerifyClaimantSerializer)
            .to receive(:new)
            .with(verify_claimant_response)
            .and_return(serializer)
        end

        context 'when the service returns a successful response' do
          it 'calls the verify_claimant_service' do
            expect_any_instance_of(Vye::DGIB::VerifyClaimant::Service).to receive(:verify_claimant)

            # You have to do this or the test will fail.
            # Something buried in pundit is preventing it from working without it
            # Consequently, no separate test for pundit
            expect(controller).to receive(:authorize).with(@current_user, policy_class: UserInfoPolicy).and_return(true)

            subject.params =
              { claimant_id:, verified_period_begin_date:, verified_period_end_date:, verfied_through_date: }

            subject.verify_claimant
          end

          it 'renders the serialized response with a 200 status' do
            # You have to do this or the test will fail.
            # Something buried in pundit is preventing it from working without it
            # Consequently, no separate test for pundit
            expect(controller).to receive(:authorize).with(@current_user, policy_class: UserInfoPolicy).and_return(true)

            # Chatgpt says do this, but it does not work:
            # expect(controller).to receive(:render).with(json: serializer.new(claimant_service_response).to_json)
            # What works is this
            expect(controller).to receive(:render).with(json: serializer.serializable_hash.to_json)

            subject.params =
              { claimant_id:, verified_period_begin_date:, verified_period_end_date:, verfied_through_date: }

            subject.verify_claimant
            expect(serializer.status).to eq(200)
          end
        end
      end

      def create_verify_claimant_response
        response_struct = Struct.new(:body)
        response = response_struct.new(
          {
            'claimant_id' => 1,
            'delimiting_date' => '2024-11-01',
            'verified_details' => {
              'benefit_type' => 'CH33',
              'verification_through_date' => '2024-11-01',
              'verification_method' => 'Initial'
            },
            'payment_on_hold' => true
          }
        )

        Vye::DGIB::VerifyClaimant::Response.new(200, response)
      end

      describe '#verification_record' do
        let(:verification_record_response) { create_verification_record_response }
        let(:serializer) { Vye::ClaimantVerificationSerializer.new(verification_record_response) }

        before do
          allow_any_instance_of(Vye::UserInfoPolicy).to receive(:verification_record?).and_return(true)
          allow_any_instance_of(Vye::DGIB::VerificationRecord::Service)
            .to receive(:get_verification_record)
            .and_return(verification_record_response)

          allow(Vye::VerificationRecordSerializer)
            .to receive(:new)
            .with(verification_record_response)
            .and_return(serializer)
        end
      end

      context 'when the service returns a successful response' do
        it 'calls the verification_record_service' do
          expect_any_instance_of(Vye::DGIB::VerificationRecord::Service).to receive(:get_verification_record)

          # You have to do this or the test will fail.
          # Something buried in pundit is preventing it from working without it
          # Consequently, no separate test for pundit
          expect(controller).to receive(:authorize).with(@current_user, policy_class: UserInfoPolicy).and_return(true)

          subject.params = { claimant_id: }
          subject.verification_record
        end

        it 'renders the serialized response with a 200 status' do
          # You have to do this or the test will fail.
          # Something buried in pundit is preventing it from working without it
          # Consequently, no separate test for pundit
          expect(controller).to receive(:authorize).with(@current_user, policy_class: UserInfoPolicy).and_return(true)

          # Chatgpt says do this, but it does not work:
          # expect(controller).to receive(:render).with(json: serializer.new(claimant_service_response).to_json)
          # What works is this
          expect(controller).to receive(:render).with(json: serializer.serializable_hash.to_json)

          subject.params = { claimant_id: }
          subject.verification_record
          expect(serializer.status).to eq(200)
        end
      end

      def create_verification_record_response
        response_struct = Struct.new(:body)
        response = response_struct.new(
          {
            'claimant_id' => 1,
            'delimiting_date' => '2024-11-01',
            'verified_details' => {
              'benefit_type' => 'CH33',
              'verification_through_date' => '2024-11-01',
              'verification_method' => 'Initial'
            },

            'enrollment_verifications' => {
              'verification_month' => 'December 2023',
              'verification_begin_date' => '2024-11-01',
              'verification_end_date' => '2024-11-30',
              'verification_through_date' => '2024-11-30',
              'created_date' => '2024-11-01',
              'verification_method' => 'VYE',
              'verification_response' => 'Y',
              'facility_name' => 'University of Texas Austin',
              'total_credit_hours' => '72',
              'payment_transmission_date' => '2024-10-15',
              'last_deposit_amount' => '4500.00',
              'remaining_entitlement' => '12-31'
            },

            'payment_on_hold' => true
          }
        )

        Vye::DGIB::VerificationRecord::Response.new(200, response)
      end
    end
  end
end
