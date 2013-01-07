module Gridzilla

  module ViewDsl

    class Base
      def initialize(dsl, context)
        @dsl = dsl
        @chain = [@dsl, context]
      end

      def method_missing(name, *args, &block)
        result = nil
        @chain.each do |receiver|
          begin
            if receiver.respond_to?(name) or receiver.respond_to?(:method_missing)
              result = receiver.send(name, *args, &block)
              break
            end
          rescue Exception => e
            if Rails.env.development?
              raise e
            else
              next
            end
          end
        end

        result
      end
    end

  end

end
