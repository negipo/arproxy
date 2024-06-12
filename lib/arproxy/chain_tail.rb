module Arproxy
  class ChainTail < Base
    def initialize(proxy_chain)
      self.proxy_chain = proxy_chain
    end

    def execute(sql, name = nil, **kwargs)
      proxy_chain.connection.send :execute_without_arproxy, sql, name, **kwargs
    end

    def exec_query(sql, name = nil, binds = [], **kwargs)
      proxy_chain.connection.send :exec_query_without_arproxy, sql, name, binds, **kwargs
    end

    def internal_exec_query(sql, name = nil, binds = [], **kwargs)
      proxy_chain.connection.send :internal_exec_query_without_arproxy, sql, name, binds, **kwargs
    end
  end
end
