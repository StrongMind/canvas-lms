# frozen_string_literal: true

class GrowthbookService
  CACHE_KEY = 'growthbook_features'
  CACHE_TTL = 1.minute

  def self.enabled?(flag_key, attributes: nil)
    return true if Rails.env.development?

    attributes ||= {}
    new.enabled?(flag_key, attributes:)
  end

  def enabled?(flag_key, attributes: {})
    context = Growthbook::Context.new(
      features: features_json,
      attributes: attributes || {}
    )
    context.on?(flag_key)
  end

  private

  def features_json
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      Growthbook::FeatureRepository.new(endpoint:, decryption_key: nil).fetch || {}
    end
  rescue StandardError => e
    Rails.logger.warn("GrowthBook feature fetch failed: #{e.message}")
    {}
  end

  def endpoint
    @endpoint ||= ENV.fetch('GROWTHBOOK_ENDPOINT', nil)
  end
end
