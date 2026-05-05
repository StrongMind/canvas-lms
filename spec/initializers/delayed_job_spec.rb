#
# Copyright (C) 2014 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

require File.expand_path('../sharding_spec_helper', File.dirname( __FILE__ ))

describe 'Delayed::Job' do
  shared_examples_for "delayed_jobs_shards" do
    it "should keep track of the current shard on child jobs" do
      shard = @shard1 || Shard.default
      shard.activate do
        Delayed::Batch.serial_batch {
          expect("string".send_later_enqueue_args(:size, no_delay: true)).to be true
          expect("string".send_later_enqueue_args(:gsub, { no_delay: true }, /./, "!")).to be true
        }
      end
      job = Delayed::Job.find_available(1).first
      expect(job.current_shard).to eq shard
      expect(job.payload_object.jobs.first.current_shard).to eq shard
    end
  end

  describe "current_shard" do
    include_examples "delayed_jobs_shards"

    context "sharding" do
      specs_require_sharding
      include_examples "delayed_jobs_shards"
    end
  end
end

describe "JobStalenessMetric.publish" do
  let(:now) { Time.zone.parse("2026-05-01 10:00:00 UTC") }
  let(:cloudwatch_client) { instance_double(Aws::CloudWatch::Client) }
  let(:relation) { instance_double(ActiveRecord::Relation) }

  def with_job_staleness_metric_flag(value)
    previous = ENV["JOB_STALENESS_METRIC_ENABLED"]
    value.nil? ? ENV.delete("JOB_STALENESS_METRIC_ENABLED") : ENV["JOB_STALENESS_METRIC_ENABLED"] = value
    yield
  ensure
    previous.nil? ? ENV.delete("JOB_STALENESS_METRIC_ENABLED") : ENV["JOB_STALENESS_METRIC_ENABLED"] = previous
  end

  before do
    Thread.current[JobStalenessMetric::NEXT_PUBLISH_AT_KEY] = nil
    allow(Aws::CloudWatch::Client).to receive(:new).with(region: "us-west-2").and_return(cloudwatch_client)
    allow(cloudwatch_client).to receive(:put_metric_data)
    allow(Rails.logger).to receive(:warn)

    allow(Time).to receive(:now).and_return(now)
    allow(Delayed::Job).to receive(:where).with(attempts: 0).and_return(relation)
    allow(relation).to receive(:where).with(locked_at: nil).and_return(relation)
    allow(relation).to receive(:where).with(next_in_strand: false).and_return(relation)
    allow(relation).to receive(:where).with("run_at <= ?", instance_of(DateTime)).and_return(relation)
    allow(relation).to receive(:minimum).with(:run_at).and_return(DateTime.now.utc - Rational(1, 24))
  end

  after do
    Thread.current[JobStalenessMetric::NEXT_PUBLISH_AT_KEY] = nil
  end

  it "skips when metric flag is unset" do
    with_job_staleness_metric_flag(nil) do
      JobStalenessMetric.publish
    end

    expect(cloudwatch_client).not_to have_received(:put_metric_data)
  end

  it "skips when metric flag is not true" do
    with_job_staleness_metric_flag("false") do
      JobStalenessMetric.publish
    end

    expect(cloudwatch_client).not_to have_received(:put_metric_data)
  end

  it "publishes once when enabled" do
    with_job_staleness_metric_flag("true") do
      JobStalenessMetric.publish
    end

    expect(cloudwatch_client).to have_received(:put_metric_data).once
  end

  it "throttles repeated calls within one minute on the same thread" do
    with_job_staleness_metric_flag("true") do
      JobStalenessMetric.publish
      JobStalenessMetric.publish
    end

    expect(cloudwatch_client).to have_received(:put_metric_data).once
  end

  it "publishes again after one minute has passed" do
    allow(Time).to receive(:now).and_return(now, now + 61.seconds)

    with_job_staleness_metric_flag("true") do
      JobStalenessMetric.publish
      JobStalenessMetric.publish
    end

    expect(cloudwatch_client).to have_received(:put_metric_data).twice
  end

  it "rescues and logs when cloudwatch publish raises" do
    allow(cloudwatch_client).to receive(:put_metric_data).and_raise(StandardError.new("publish failure"))

    with_job_staleness_metric_flag("true") do
      expect { JobStalenessMetric.publish }.not_to raise_error
    end

    expect(Rails.logger).to have_received(:warn).with(/JobStaleness/)
  end

  it "rescues and logs when querying delayed jobs raises" do
    allow(Delayed::Job).to receive(:where).with(attempts: 0).and_raise(StandardError.new("db failure"))

    with_job_staleness_metric_flag("true") do
      expect { JobStalenessMetric.publish }.not_to raise_error
    end

    expect(Rails.logger).to have_received(:warn).with(/JobStaleness/)
  end
end
