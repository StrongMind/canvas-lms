require_relative '../../rails_helper'

RSpec.describe PipelineService::Serializers do
  describe '#names' do
    it 'list the names of the serializers' do
      expect(described_class.names).to include(:User)
    end
    it 'does not include base methods' do
      expect(described_class.names).to_not include(:BaseMethods)
    end
  end

  describe '#repositories' do
    it 'returns repositories' do
      expect(described_class.repositories).to include(::User)
    end

    it 'does not include serializers that do not use repos' do
      expect(described_class.repositories).to_not include(PipelineService::Serializers::CanvasAPIEnrollment)
    end

  end

  describe '#list' do
    it 'returns the serializers' do
      expect(described_class.list).to include(PipelineService::Serializers::User)
    end
  end
end