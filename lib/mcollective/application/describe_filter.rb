module MCollective
  class Application::Describe_filter < Application # rubocop:disable Style/ClassAndModuleChildren
    exclude_argument_sections "common", "rpc"

    description "Display human readable interpretation of filters"

    usage "mco describe_filter -S <filter> -F <filter> -C <filter>"

    def describe_s_filter(stack)
      indent = "  "
      old_indent = "  "
      puts "-S Query expands to the following instructions:"
      puts
      stack.each do |token|
        case token.keys[0]
        when "statement"
          if token.values[0] =~ /(<=|>=|=|=~|=)/
            op = $1
            k, v = token.values[0].split(op)
            puts indent + get_fact_string(k, v, op)
          else
            puts indent + get_class_string(token.values[0])
          end
        when "fstatement"
          v = token.values[0]
          result_string = indent + "Execute the Data Query '#{v['name']}'"
          result_string += " with parameters (#{v['params']})" if v["params"]
          result_string += ". "
          result_string += "Check if the query's '#{v['value']}' value #{v['operator']} '#{v['r_compare']}'  "
          puts result_string
        when "("
          puts "#{indent}("
          old_indent = indent
          indent *= 2
        when ")"
          indent = old_indent
          puts "#{indent})"
        else
          puts indent + token.keys[0].upcase
        end
      end
    end

    def describe_f_filter(facts)
      puts "-F filter expands to the following fact comparisons:"
      puts
      facts.each do |f|
        puts "  #{get_fact_string(f[:fact], f[:value], f[:operator])}"
      end
    end

    def describe_c_filter(classes)
      puts "-C filter expands to the following class checks:"
      puts
      classes.each do |c|
        puts "  #{get_class_string(c)}"
      end
    end

    def main
      unless @options[:filter]["fact"].empty?
        describe_f_filter(@options[:filter]["fact"])
        puts
      end

      unless @options[:filter]["cf_class"].empty?
        describe_c_filter(@options[:filter]["cf_class"])
        puts
      end

      unless @options[:filter]["compound"].empty?
        describe_s_filter(@options[:filter]["compound"][0])
        puts
      end
    end

    private

    def get_fact_string(fact, value, oper)
      "Check if fact '#{fact}' #{oper} '#{value}'"
    end

    def get_class_string(classname)
      "Check if class '#{classname}' is present on the host"
    end
  end
end
