module MCollective
  module Validator
    class TypecheckValidator
      def self.validate(validator, validation_type)
        raise ValidatorError, "value should be a #{validation_type}" unless check_type(validator, validation_type)
      end

      def self.check_type(validator, validation_type)
        case validation_type
        when Class
          validator.is_a?(validation_type)
        when :integer
          validator.is_a?(Integer)
        when :float
          validator.is_a?(Float) || validator.is_a?(Integer)
        when :number
          validator.is_a?(Numeric)
        when :string
          validator.is_a?(String)
        when :boolean
          [TrueClass, FalseClass].include?(validator.class)
        when :array
          validator.is_a?(Array)
        when :hash
          validator.is_a?(Hash)
        else
          false
        end
      end
    end
  end
end
