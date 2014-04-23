require 'mongoid'
require 'siv'
require 'sse'
require 'ope'
require 'cmac'

require 'openssl'
require 'stringio'
require 'ap'

module Cryodex
  
  
  def self.generate_key(table, col)
    
    #key = ["2b7e151628aed2a6abf7158809cf4f3c"].pack('H*')
    #
    #cmac = CMAC::Digest.new(key)
    #
    #digest = cmac.update(table + col)
    #digest.unpack('H*')[0]
    
    "2b7e151628aed2a6abf7158809cf4f3c2b7e151628aed2a6abf7158809cf4f3c"
    
  end

end

module Moped
  
  class Node
    
    Base64Regexp = /^(?:[A-Za-z0-9+\/]{4}\n?)*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?$/
    
    def process(operation, &callback)
      
      after_query = lambda do |*args, &block|
        
        args.each do |arg|
          
          next unless arg
          
          documents = arg.instance_eval { @documents }
          
          if documents && !documents.empty?
            
            documents.each_with_index do |document, index|
              
              table = document['_table']
              next unless table
              
              document.each do |key, str|
     
                crypto_key = Cryodex.generate_key(table, key)
                
                ct = nil
                
                if str.is_a?(Numeric)
                  
                  if str > 1
                    
                    cipher = OPE::Cipher.new(crypto_key.byteslice(0, 16), 4, 8)
                    ct = cipher.decrypt(str)
                  
                  else
                    
                    ct = str
                    
                  end
                  
                elsif str.is_a?(String) && str.match(Base64Regexp)
                  
                  cipher = SIV::Cipher.new(crypto_key)

                  ct = Base64.strict_decode64(str)
                  ct = cipher.decrypt(ct, [])
                  
                else
                  
                  ct = str
                  
                end
                                
                arg.instance_eval do
                  @documents[index][key] = ct
                end
                
              end
              
            end
            
          end
          
        end
        
        callback.call(*args, &block) if callback
        
      end
      
      collection = operation.instance_eval { @full_collection_name }
      
      
      # Only encrypt data stored in collections
      if collection && !collection.index('$cmd')
        
        selector = operation.instance_eval { @selector }
        documents = operation.instance_eval { @documents }
      
        if selector
        
          selector = encrypt_recurse(selector, collection, false)
          operation.instance_eval { @selector = selector }
          
        elsif documents
          documents = documents.map do |d|
            encrypt_recurse(d.dup, collection, true)
          end
          operation.instance_eval { @documents = documents }
        elsif operation.is_a?(Moped::Protocol::GetMore)
          # do nothing
        else
          raise 'should not happen'
        end
        
      end
      
      if Threaded.executing? :pipeline
        queue.push [operation, after_query]
      else
        flush([[operation, after_query]])
      end
      
    end

    def encrypt_recurse(selector, collection, flag2)

      return unless selector

      flag = false
      
      selector.each do |key, val|

        ct = if val.is_a?(Hash)
          encrypt_recurse(val, collection, flag2)
        elsif val.is_a?(Array)
          val.map do |value|
            encrypt(key.to_s, value, collection)
          end
        else
          next if key == '_id'
          flag = true
          encrypt(key.to_s, val, collection)
        end
        
        selector[key] = ct

      end
      
      selector['_table'] = collection if flag && flag2
      
      selector

    end
  
    def encrypt(key, val, collection)

      crypto_key = Cryodex.generate_key(collection, key)
      
      if val.is_a?(String)

        cipher = SIV::Cipher.new(crypto_key)

        Base64.strict_encode64(cipher.encrypt(val, []))
      
     elsif val.is_a?(Numeric) && val > 1
        
        cipher = OPE::Cipher.new(crypto_key.byteslice(0, 16), 4, 8)
        cipher.encrypt(val)
      
      else
        
        val
        
      end

    end
    
  end
  
end

require 'mongoid_search'

Mongoid::Search::ClassMethods.module_eval do
  
  def query(keywords, options)
    
    crypto_key = Cryodex.generate_key(nil, nil)
    
    cipher = SIV::Cipher.new(crypto_key)
    
    keywords_hash = keywords.map do |kw|
      { :_keywords => Base64.strict_encode64(cipher.encrypt(kw, [])) }
    end

    criteria.send("#{(options[:match]).to_s}_of", *keywords_hash)
    
  end
  
end