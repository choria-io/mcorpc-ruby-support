module MCollective
  class Aggregate
    require "mcollective/aggregate/result"
    require "mcollective/aggregate/base"

    attr_accessor :ddl, :functions, :action, :failed

    def initialize(ddl)
      @functions = []
      @ddl = ddl
      @action = ddl[:action]
      @failed = []

      create_functions
    end

    # Creates instances of the Aggregate functions and stores them in the function array.
    # All aggregate call and summarize method calls operate on these function as a batch.
    def create_functions
      @ddl[:aggregate].each_with_index do |agg, _i|
        output = agg[:args][0]

        if contains_output?(output)
          arguments = agg[:args][1]
          format = (arguments.delete(:format) if arguments) || nil
          begin
            @functions << load_function(agg[:function]).new(output, arguments, format, @action)
          rescue Exception => e
            Log.error("Cannot create aggregate function '%s': %s" % [output, e])
            @failed << {:name => output, :type => :startup}
          end
        else
          Log.error("Cannot create aggregate function '%s'. '%s' has not been specified as a valid ddl output." % [output, output])
          @failed << {:name => output, :type => :create}
        end
      end
    end

    # Check if the function param is defined as an output for the action in the ddl
    def contains_output?(output)
      @ddl[:output].keys.include?(output)
    end

    # Call all the appropriate functions with the reply data received from RPC::Client
    def call_functions(reply)
      @functions.each do |function|
        Log.debug("Calling aggregate function %s for result" % function)
        begin
          function.process_result(reply[:data][function.output_name], reply)
        rescue Exception => e
          Log.error("Could not process aggregate function for '%s': %s" % [function.output_name, e])
          @failed << {:name => function.output_name, :type => :process_result}
          @functions.delete(function)
        end
      end
    end

    # Finalizes the function returning a result object
    def summarize
      summary = @functions.map do |function|
        begin
          function.summarize
        rescue Exception => e
          Log.error("Could not summarize aggregate result for '%s': %s" % [function.output_name, e])
          @failed << {:name => function.output_name, :type => :summarize}
          nil
        end
      end

      summary.reject(&:nil?).sort do |x, y|
        x.result[:output] <=> y.result[:output]
      end
    end

    # Loads function from disk for use
    def load_function(function_name)
      function_name = function_name.to_s.capitalize

      PluginManager.loadclass("MCollective::Aggregate::%s" % function_name) unless Aggregate.const_defined?(function_name)
      Aggregate.const_get(function_name)
    rescue Exception
      raise("Aggregate function file '%s.rb' cannot be loaded" % function_name.downcase)
    end
  end
end
