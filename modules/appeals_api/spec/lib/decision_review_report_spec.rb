# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/decision_review_report'

describe AppealsApi::DecisionReviewReport do
  # rubocop:disable Layout/FirstHashElementIndentation
  it 'can correctly calculate hlrs' do
    create :higher_level_review, status: 'processing'
    create :higher_level_review, status: 'processing'
    create :higher_level_review, status: 'processing'

    create :higher_level_review, created_at: 1.week.ago, status: 'success'
    create :higher_level_review, status: 'success'
    create :higher_level_review, status: 'success'

    create :higher_level_review, :status_error

    subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

    expect(subject.hlr_by_status_and_count).to eq({
      'caseflow' => 0,
      'error' => 1,
      'expired' => 0,
      'pending' => 0,
      'processing' => 3,
      'received' => 0,
      'submitted' => 0,
      'submitting' => 0,
      'success' => 2,
      'uploaded' => 0
    })
  end

  describe '#faulty_hlr' do
    let(:old_error) { create(:higher_level_review, :status_error, created_at: 1.year.ago) }
    let(:recent_error) { create(:higher_level_review, :status_error, created_at: 1.day.ago) }

    it 'will retrieve recent errored records if dates are provided' do
      subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

      expect(subject.faulty_hlr).to eq([recent_error])
    end

    it 'will retrieve all errored records if no dates are provided' do
      subject = described_class.new(from: nil, to: nil)

      expect(subject.faulty_hlr).to eq([recent_error, old_error])
    end
  end

  it 'can correctly calculate nods' do
    create :notice_of_disagreement, created_at: 1.week.ago, status: 'success'
    create :notice_of_disagreement, status: 'success'
    create :notice_of_disagreement, status: 'success'

    create :notice_of_disagreement, :status_error

    subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

    expect(subject.nod_by_status_and_count).to eq({
      'error' => 1,
      'pending' => 0,
      'processing' => 0,
      'submitted' => 0,
      'submitting' => 0,
      'success' => 2,
      'caseflow' => 0
    })
  end

  describe '#faulty_nod' do
    let(:old_error) { create(:notice_of_disagreement, :status_error, created_at: 1.year.ago) }
    let(:recent_error) { create(:notice_of_disagreement, :status_error, created_at: 1.day.ago) }

    it 'will retrieve recent errored records if dates are provided' do
      subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

      expect(subject.faulty_nod).to eq([recent_error])
    end

    it 'will retrieve all errored records if no dates are provided' do
      subject = described_class.new(from: nil, to: nil)

      expect(subject.faulty_nod).to eq([recent_error, old_error])
    end
  end

  it 'can correctly calculate SCs' do
    create :supplemental_claim, created_at: 1.week.ago, status: 'success'
    create :supplemental_claim, :status_success
    create :supplemental_claim, :status_success

    create :supplemental_claim, :status_error

    subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

    expect(subject.sc_by_status_and_count).to eq({
      'error' => 1,
      'pending' => 0,
      'success' => 2
    })
  end

  describe '#faulty_sc' do
    let(:old_error) { create(:supplemental_claim, :status_error, created_at: 1.year.ago) }
    let(:recent_error) { create(:supplemental_claim, :status_error, created_at: 1.day.ago) }

    it 'will retrieve recent errored records if dates are provided' do
      subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

      expect(subject.faulty_sc).to eq([recent_error])
    end

    it 'will retrieve all errored records if no dates are provided' do
      subject = described_class.new(from: nil, to: nil)

      expect(subject.faulty_sc).to eq([recent_error, old_error])
    end
  end

  describe 'evidence submissions' do
    describe 'nod' do
      let!(:evidence_submission_1) { create(:evidence_submission) }
      let!(:evidence_submission_2) { create(:evidence_submission, created_at: 1.week.ago) }

      describe '#evidence_submission_by_status_and_count' do
        it 'will retrieve recent errored records if dates are provided' do
          subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

          expect(subject.evidence_submission_by_status_and_count).to eq({
            'error' => 0,
            'expired' => 0,
            'pending' => 1,
            'processing' => 0,
            'received' => 0,
            'success' => 0,
            'uploaded' => 0,
            'vbms' => 0
          })
        end

        it 'will retrieve all errored records if no dates are provided' do
          subject = described_class.new(from: nil, to: nil)

          expect(subject.evidence_submission_by_status_and_count).to eq({
            'error' => 0,
            'expired' => 0,
            'pending' => 2,
            'processing' => 0,
            'received' => 0,
            'success' => 0,
            'uploaded' => 0,
            'vbms' => 0
          })
        end
      end

      describe '#faulty_evidence_submission' do
        let(:recent_error) { create(:evidence_submission, :status_error, created_at: 1.day.ago) }
        let(:old_error) { create(:evidence_submission, :status_error, created_at: 1.year.ago) }

        it 'will retrieve recent errored records if dates are provided' do
          subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

          expect(subject.faulty_evidence_submission).to eq([recent_error])
        end

        it 'will retrieve all errored records if no dates are provided' do
          subject = described_class.new(from: nil, to: nil)

          expect(subject.faulty_evidence_submission).to eq([recent_error])
        end
      end
    end

    describe 'sc' do
      describe '#evidence_submission_by_status_and_count' do
        it 'will retrieve recent errored records if dates are provided' do
          create(:sc_evidence_submission)
          create(:sc_evidence_submission, created_at: 1.week.ago)
          create(:evidence_submission)

          subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

          expect(subject.sc_evidence_submission_by_status_and_count).to eq({
            'error' => 0,
            'expired' => 0,
            'pending' => 1,
            'processing' => 0,
            'received' => 0,
            'success' => 0,
            'uploaded' => 0,
            'vbms' => 0
          })
        end

        it 'will retrieve all errored records if no dates are provided' do
          create(:sc_evidence_submission)
          create(:sc_evidence_submission, created_at: 1.week.ago)
          create(:evidence_submission)

          subject = described_class.new(from: nil, to: nil)

          expect(subject.sc_evidence_submission_by_status_and_count).to eq({
            'error' => 0,
            'expired' => 0,
            'pending' => 2,
            'processing' => 0,
            'received' => 0,
            'success' => 0,
            'uploaded' => 0,
            'vbms' => 0
          })
        end
      end

      describe '#faulty_evidence_submission' do
        let!(:recent_evidence_submission_error) { create(:evidence_submission, :status_error, created_at: 1.day.ago) }
        let(:recent_error) { create(:sc_evidence_submission, :status_error, created_at: 1.day.ago) }
        let(:old_error) { create(:sc_evidence_submission, :status_error, created_at: 1.year.ago) }

        it 'will retrieve recent errored records if dates are provided' do
          subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

          expect(subject.sc_faulty_evidence_submission).to eq([recent_error])
        end

        it 'will retrieve all errored records if no dates are provided' do
          subject = described_class.new(from: nil, to: nil)

          expect(subject.sc_faulty_evidence_submission).to eq([recent_error])
        end
      end
    end
  end
  # rubocop:enable Layout/FirstHashElementIndentation

  describe '#no_faulty_records?' do
    it 'returns false if there are records with a faulty status' do
      create :notice_of_disagreement, :status_error

      expect(described_class.new.no_faulty_records?).to eq(false)
    end

    it 'returns true if there are no records with a faulty status' do
      expect(described_class.new.no_faulty_records?).to eq(true)
    end
  end
end
