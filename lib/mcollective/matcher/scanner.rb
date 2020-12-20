module MCollective
  module Matcher
    class Scanner
      attr_accessor :arguments, :token_index

      def initialize(arguments)
        @token_index = 0
        @arguments = arguments.split("")
        @seperation_counter = 0
        @white_spaces = 0
      end

      # Scans the input string and identifies single language tokens
      def get_token # rubocop:disable Naming/AccessorMethodName
        return nil if @token_index >= @arguments.size

        case @arguments[@token_index]
        when "("
          ["(", "("]

        when ")"
          [")", ")"]

        when "n"
          if (@arguments[@token_index + 1] == "o") && (@arguments[@token_index + 2] == "t") && ((@arguments[@token_index + 3] == " ") || (@arguments[@token_index + 3] == "("))
            @token_index += 2
            ["not", "not"]
          else
            gen_statement
          end

        when "!"
          ["not", "not"]

        when "a"
          if (@arguments[@token_index + 1] == "n") && (@arguments[@token_index + 2] == "d") && ((@arguments[@token_index + 3] == " ") || (@arguments[@token_index + 3] == "("))
            @token_index += 2
            ["and", "and"]
          else
            gen_statement
          end

        when "o"
          if (@arguments[@token_index + 1] == "r") && ((@arguments[@token_index + 2] == " ") || (@arguments[@token_index + 2] == "("))
            @token_index += 1
            ["or", "or"]
          else
            gen_statement
          end

        when " "
          [" ", " "]

        else
          gen_statement
        end
      end

      private

      # Helper generates a statement token
      def gen_statement # rubocop:disable Metrics/MethodLength
        func = false
        current_token_value = ""
        j = @token_index
        escaped = false

        begin
          case @arguments[j]
          when "/"
            loop do
              current_token_value << @arguments[j]
              j += 1
              break if (j >= @arguments.size) || (@arguments[j] =~ /\s/)
            end
          when /=|<|>/
            while @arguments[j] !~ /=|<|>/
              current_token_value << @arguments[j]
              j += 1
            end

            current_token_value << @arguments[j]
            j += 1

            if @arguments[j] == "/"
              loop do
                current_token_value << @arguments[j]
                j += 1
                if @arguments[j] == "/"
                  current_token_value << "/"
                  break
                end
                break if (j >= @arguments.size) || (@arguments[j] =~ /\//)
              end
              while (j < @arguments.size) && ((@arguments[j] != " ") && (@arguments[j] != ")"))
                current_token_value << @arguments[j]
                j += 1
              end
            end
          else
            loop do
              # Identify and tokenize regular expressions by ignoring everything between /'s
              if @arguments[j] == "/"
                current_token_value << "/"
                j += 1
                while j < @arguments.size && @arguments[j] != "/"
                  if @arguments[j] == '\\' # rubocop:disable Metrics/BlockNesting
                    # eat the escape char
                    current_token_value << @arguments[j]
                    j += 1
                    escaped = true
                  end

                  current_token_value << @arguments[j]
                  j += 1
                end
                current_token_value << @arguments[j] if @arguments[j]
                break
              end

              case @arguments[j]
              when "("
                func = true

                current_token_value << @arguments[j]
                j += 1

                while j < @arguments.size
                  current_token_value << @arguments[j]
                  if @arguments[j] == ")" # rubocop:disable Metrics/BlockNesting
                    j += 1
                    break
                  end
                  j += 1
                end
              when '"', "'"
                escaped = true
                escaped_with = @arguments[j]

                j += 1 # step over first " or '
                @white_spaces += 1
                # identified "..." or '...'
                # rubocop:disable Metrics/BlockNesting
                while j < @arguments.size
                  case @arguments[j]
                  when '\\'
                    # eat the escape char but don't add it to the token, or we
                    # end up with \\\"
                    j += 1
                    @white_spaces += 1
                    break unless j < @arguments.size
                  when escaped_with
                    j += 1
                    @white_spaces += 1
                    break
                  end
                  current_token_value << @arguments[j]
                  j += 1
                end
                # rubocop:enable Metrics/BlockNesting
              else
                current_token_value << @arguments[j]
                j += 1
              end

              break if @arguments[j] == " " && (is_klass?(j) && @arguments[j - 1] !~ /=|<|>/)

              if (@arguments[j] == " ") && (@seperation_counter < 2) && !current_token_value.match(/^.+(=|<|>).+$/) && (index = lookahead(j))
                j = index
              end
              break if (j >= @arguments.size) || (@arguments[j] =~ /\s|\)/)
            end
            @seperation_counter = 0
          end
        rescue Exception => e # rubocop:disable Lint/RescueException
          raise "An exception was raised while trying to tokenize '#{current_token_value} - #{e}'"
        end

        @token_index += current_token_value.size + @white_spaces - 1
        @white_spaces = 0

        # bar(
        if current_token_value.match(/.+?\($/)
          ["bad_token", [@token_index - current_token_value.size + 1, @token_index]]
        # /foo/=bar
        elsif current_token_value.match(/^\/.+?\/(<|>|=).+/)
          ["bad_token", [@token_index - current_token_value.size + 1, @token_index]]
        elsif current_token_value.match(/^.+?\/(<|>|=).+/)
          ["bad_token", [@token_index - current_token_value.size + 1, @token_index]]
        elsif func
          if current_token_value.match(/^.+?\((\s*(')[^']*(')\s*(,\s*(')[^']*('))*)?\)(\.[a-zA-Z0-9_]+)?((!=|<=|>=|=|>|<).+)?$/) ||
             current_token_value.match(/^.+?\((\s*(")[^"]*(")\s*(,\s*(")[^"]*("))*)?\)(\.[a-zA-Z0-9_]+)?((!=|<=|>=|=|>|<).+)?$/)
            ["fstatement", current_token_value]
          else
            ["bad_token", [@token_index - current_token_value.size + 1, @token_index]]
          end
        else
          return "statement", current_token_value if escaped

          slash_err = false
          current_token_value.split("").each do |c|
            slash_err = !slash_err if c == "/"
          end
          return "bad_token", [@token_index - current_token_value.size + 1, @token_index] if slash_err

          ["statement", current_token_value]
        end
      end

      # Deal with special puppet class statement
      def is_klass?(klass)
        klass += 1 while klass < @arguments.size && @arguments[klass] == " "

        if @arguments[klass] =~ /=|<|>/
          false
        else
          true
        end
      end

      # Eat spaces while looking for the next comparison symbol
      def lookahead(index)
        index += 1
        while index <= @arguments.size
          @white_spaces += 1
          unless @arguments[index] =~ /\s/
            @seperation_counter += 1
            return index
          end
          index += 1
        end
        nil
      end
    end
  end
end
