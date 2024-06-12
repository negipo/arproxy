module Arproxy
  class Base
    attr_accessor :proxy_chain, :next_proxy

    def execute(sql, name = nil, **kwargs)
      next_proxy.send :execute, sql, name, **kwargs
    end

    def exec_query(sql, name = nil, binds = [], **kwargs)
      next_proxy.send :exec_query, sql, name, binds, **kwargs
    end

    def internal_exec_query(sql, name = nil, binds = [], **kwargs)
      next_proxy.send :internal_exec_query, sql, name, binds, **kwargs
    end
  end
end
