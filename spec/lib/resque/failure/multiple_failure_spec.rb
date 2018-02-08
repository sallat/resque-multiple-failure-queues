require 'spec_helper'
require 'resque/failure/multiple_failure'
require 'resque/failure/base'

module Resque
  module Failure
    RSpec.describe MultipleFailure do
      class TestException
        def backtrace
          'something went wrong here'
        end
      end

      class JobClass;end

      class AnotherJobClass
        def self.retry_limit
          5
        end

        def self.retry_count
          4
        end
      end

      let(:multiple_failure) {
        MultipleFailure.new(exception, worker, queue, payload)
      }

      let(:exception) { TestException.new }
      let(:worker) { 'WorkerName' }
      let(:queue) { 'queue_name' }
      let(:payload) { { 'class' => job_class } }
      let(:job_class) { 'Resque::Failure::JobClass' }

      describe '#save' do
        subject { multiple_failure.save }

        let(:data) do
          {
            failed_at: time,
            payload: payload,
            exception: 'Resque::Failure::TestException',
            error: exception.to_s,
            backtrace: ['something went wrong here'],
            worker: worker,
            queue: queue,
          }
        end

        let(:time) { '2018-02-07 11:41:12' }
        let(:encoded_data) { "{\"failed_at\":\"2018/02/07 11:41:12\"}" }
        let(:redis) { double('Redis') }

        before do
          allow(Time).to receive_message_chain(:now, :strftime) { time }
          allow(Resque).to receive(:encode).with(data).and_return(encoded_data)
        end

        it 'sends the job to the fail queue' do
          expect(Resque).to receive(:redis).and_return(redis)
          expect(redis).to receive(:rpush).with(
            :failed_queue_name, encoded_data
          )

          subject
        end

        context 'job is implementing retries' do
          let(:job_class) { 'Resque::Failure::AnotherJobClass' }

          it 'does not send job to fail queue when retrying' do
            expect(Resque).not_to receive(:redis)

            subject
          end

          context 'retries have reached the retry limit' do
            before do
              allow(Resque::Failure::AnotherJobClass).to receive(:retry_count).
                and_return(5)
            end

            it 'sends the job to the fail queue' do
              expect(Resque).to receive(:redis).and_return(redis)
              expect(redis).to receive(:rpush).with(
                :failed_queue_name, encoded_data
              )

              subject
            end
          end
        end
      end
    end
  end
end
