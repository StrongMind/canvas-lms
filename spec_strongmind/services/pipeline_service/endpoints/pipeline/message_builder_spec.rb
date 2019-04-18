require_relative '../../../../rails_helper'

RSpec.describe PipelineService::Endpoints::Pipeline::MessageBuilder do
  include_context "stubbed_network"

  let(:course) { Course.create }
  let(:user) { User.create }
  let(:enrollment) { Enrollment.create(user: user, course: course)}

  before do
    ENV['CANVAS_DOMAIN'] = 'someschool.com'
    ENV['PIPELINE_ENDPOINT'] ='endpoint'
    ENV['PIPELINE_USER_NAME'] ='canvas_stage'
    ENV['PIPELINE_PASSWORD'] ='password'
  end

  subject do
    described_class.new(
      id: 1,
      object: object
    )
  end

  let(:object) do
    PipelineService::Models::Noun.new(enrollment)
  end

  let(:message) { subject.call }

  describe "#message" do
    context 'Conversation Participant' do
      before do
        allow(PipelineService::HTTPClient).to receive(:post)
      end

      let(:conversation_participant) {
        ConversationParticipant.create(conversation_id: 2)
      }

      subject do
        described_class.new(
          id: conversation_participant.id,
          object: PipelineService::Models::Noun.new(conversation_participant)
        )
      end

      describe '#noun' do
        it 'should use an underscored version of the noun' do
          expect(message[:noun]).to eq('conversation_participant')
        end
      end
    end

    describe '#meta' do
      let!(:meta) do
        message[:meta]
      end

      it '#domain_name' do
        expect(meta[:domain_name]).to eq 'someschool.com'
      end

      it '#source' do
        expect(meta[:source]).to eq 'canvas'
      end

      it '#status' do
        expect(meta[:status]).to eq nil
      end
    end

    it '#data' do
      class_double("PipelineService::Serializers::Enrollment", new: double('instance', call: {id: 1})).as_stubbed_const
      expect(message[:data]).to eq(:id=>1)
    end

    context "when there are additional identifiers in the serializer" do
      it 'adds ids to the message identifiers' do
        expect(message[:identifiers][:course_id]).to eq course.id
        expect(message[:identifiers][:user_id]).to eq user.id
      end
    end

    context "when a record has been deleted" do
      let(:object) do
        PipelineService::Models::Noun.new(enrollment)
      end

      before do
        allow(object).to receive(:destroyed?).and_return true
      end

      it '#status' do
        expect(message[:meta][:status]).to eq 'deleted'
      end
    end

    context "when a worflow state is deleted" do
      let(:object) do
        PipelineService::Models::Noun.new(enrollment)
      end

      before do
        allow(object).to receive(:destroyed?).and_return true
      end

      it 'sets the status in meta to "deleted"' do
        expect(message[:meta][:status]).to eq('deleted')
      end
    end
  end
end
