module MCollective
  module Validator
    class LengthValidator
      def self.validate(validator, length)
        raise ValidatorError, "Input string is longer than #{length} character(s)" if (validator.size > length) && (length > 0)
      end
    end
  end
end
