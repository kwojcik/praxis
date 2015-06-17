module Praxis
  module RequestStages

    class Validate < RequestStage

      def initialize(name, context,**opts)
        super
        # Add our sub-stages
        @stages = [
          RequestStages::ValidateParamsAndHeaders.new(:params_and_headers, context, parent: self),
          RequestStages::ValidatePayload.new(:payload, context, parent: self)
        ]
      end

      def execute
        super
      rescue Attributor::AttributorException => e
        validation_handler.handle!(
          summary: "Error validating request", 
          exception: e,
          request: request,
          stage: name
        )
      end

    end

  end
end
