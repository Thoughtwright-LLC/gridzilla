require 'gridzilla/blankslate'

module Gridzilla
  class Gobbler < Gridzilla::BlankSlate
    def method_missing(meth_name, *args, &block)
      self
    end
  end
end
