module Resque
  module Failure
    module MultipleFailureHelpers
      module Retry
        def retry_limit
          @retry_limit ||= 0
        end

        def retry_count
          @retry_count ||= 0
        end
      end
    end
  end
end
