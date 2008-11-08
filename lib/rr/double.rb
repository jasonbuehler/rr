module RR
  # RR::Double is the use case for a method call.
  # It has the ArgumentEqualityExpectation, TimesCalledExpectation,
  # and the implementation.
  class Double
    class << self
      def formatted_name(method_name, args)
        formatted_errors = args.collect {|arg| arg.inspect}.join(', ')
        "#{method_name}(#{formatted_errors})"
      end

      def list_message_part(doubles)
        doubles.collect do |double|
          "- #{formatted_name(double.method_name, double.expected_arguments)}"
        end.join("\n")
      end
    end

    attr_reader :times_called, :double_injection, :definition
    include Space::Reader

    def initialize(double_injection, definition)
      @double_injection = double_injection
      @definition = definition
      @times_called = 0
      @times_called_expectation = Expectations::TimesCalledExpectation.new(self)
      definition.double = self
      verify_method_signature if definition.verify_method_signature?
      double_injection.register_double self
    end
    
    # Double#ordered? returns true when the Double is ordered.
    #
    #   mock(subject).method_name.ordered?
    def ordered?
      definition.ordered?
    end

    # Double#verbose? returns true when verbose has been called on it. It returns
    # true when the double is set to print each method call it receives.
    def verbose?
      definition.verbose?
    end

    # Double#call calls the Double's implementation. The return
    # value of the implementation is returned.
    #
    # A TimesCalledError is raised when the times called
    # exceeds the expected TimesCalledExpectation.
    def call(double_injection, *args, &block)
      if verbose?
        puts Double.formatted_name(double_injection.method_name, args)
      end
      times_called_expectation.attempt if definition.times_matcher
      space.verify_ordered_double(self) if ordered?
      yields!(block)
      return_value = call_implementation(double_injection, *args, &block)
      definition.after_call_proc ? extract_subject_from_return_value(definition.after_call_proc.call(return_value)) : return_value
    end

    def yields!(block)
      if definition.yields_value
        if block
          block.call(*definition.yields_value)
        else
          raise ArgumentError, "A Block must be passed into the method call when using yields"
        end
      end
    end
    protected :yields!

    def call_implementation(double_injection, *args, &block)
      return_value = do_call_implementation_and_get_return_value(double_injection, *args, &block)
      extract_subject_from_return_value(return_value)
    end
    protected :call_implementation

    # Double#exact_match? returns true when the passed in arguments
    # exactly match the ArgumentEqualityExpectation arguments.
    def exact_match?(*arguments)
      definition.exact_match?(*arguments)
    end

    # Double#wildcard_match? returns true when the passed in arguments
    # wildcard match the ArgumentEqualityExpectation arguments.
    def wildcard_match?(*arguments)
      definition.wildcard_match?(*arguments)
    end

    # Double#attempt? returns true when the
    # TimesCalledExpectation is satisfied.
    def attempt?
      return true unless definition.times_matcher
      times_called_expectation.attempt?
    end

    # Double#verify verifies the the TimesCalledExpectation
    # is satisfied for this double. A TimesCalledError
    # is raised if the TimesCalledExpectation is not met.
    def verify
      return true unless definition.times_matcher
      times_called_expectation.verify!
      true
    end

    def terminal?
      return false unless definition.times_matcher
      times_called_expectation.terminal?
    end

    # The method name that this Double is attatched to
    def method_name
      double_injection.method_name
    end

    # The Arguments that this Double expects
    def expected_arguments
      return [] unless argument_expectation
      argument_expectation.expected_arguments
    end

    # The TimesCalledMatcher for the TimesCalledExpectation
    def times_matcher
      times_called_expectation.matcher
    end

    def times_called_expectation
      @times_called_expectation.matcher = definition.times_matcher
      @times_called_expectation
    end

    def implementation
      definition.implementation
    end
    def implementation=(value)
      definition.implementation = value
    end
    protected :implementation=

    def argument_expectation
      definition.argument_expectation
    end
    def argument_expectation=(value)
      definition.argument_expectation = value
    end
    protected :argument_expectation=

    def formatted_name
      self.class.formatted_name(method_name, expected_arguments)
    end

    protected
    def verify_method_signature
      raise RR::Errors::SubjectDoesNotImplementMethodError if !definition.subject.respond_to?(double_injection.send(:original_method_name))
      raise RR::Errors::SubjectHasDifferentArityError if !arity_matches?
    end
    
    def subject_arity
      definition.subject.method(double_injection.send(:original_method_name)).arity
    end
    
    def subject_accepts_only_varargs?
      subject_arity == -1
    end
    
    def subject_accepts_varargs?
      subject_arity < 0
    end
    
    def arity_matches?
      return true if subject_accepts_only_varargs?
      if subject_accepts_varargs?
        return ((subject_arity * -1) - 1) <= args.size
      else
        return subject_arity == args.size
      end
    end
    
    def args
      definition.argument_expectation.expected_arguments
    end
    
    
    def do_call_implementation_and_get_return_value(double_injection, *args, &block)
      if definition.implementation_is_original_method?
        if double_injection.object_has_original_method?
          double_injection.call_original_method(*args, &block)
        else
          double_injection.subject.__send__(
            :method_missing,
            method_name,
            *args,
            &block
          )
        end
      else
        if implementation
          if implementation.is_a?(Method)
            implementation.call(*args, &block)
          else
            args << block if block
            implementation.call(*args)
          end
        else
          nil
        end
      end
    end

    def extract_subject_from_return_value(return_value)
      case return_value
      when DoubleDefinitions::DoubleDefinition
        return_value.root_subject
      when DoubleDefinitions::DoubleDefinitionCreatorProxy
        return_value.__creator__.root_subject
      else
        return_value
      end
    end
  end
end