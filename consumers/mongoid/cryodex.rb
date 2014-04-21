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
    
    def process(operation, &callback)
      
      after_query = lambda do |*args, &block|
        
        args.each do |arg|
          
          next unless arg
          
          documents = arg.instance_eval { @documents }
          
          if documents && !documents.empty?
            
            documents.each_with_index do |document, index|
              
              document.each do |key, str|
                
                next unless str.is_a?(String)

                if str[0..4] == 'cryo|'

                  parts = str.split('|')

                  table, col = parts[1].split

                  type = parts[3]

                  crypto_key = Cryodex.generate_key(table, col)
        
                  ct = nil

                  ct = if type == 'det'
                    
                    cipher = SIV::Cipher.new(crypto_key)

                    ct = Base64.strict_decode64(parts[4])
                    cipher.decrypt(ct, [])

                  elsif type == 'sse'

                    cipher = SSE::Cipher.new(crypto_key)

                    ct = parts[4].split('-').map do |p|
                      Base64.strict_decode64(p)
                    end

                    cipher.decrypt_words(crypto_key, ct).join(' ')

                  else
                    
                    raise 'unsupported cap'
                    
                  end
                  
                  arg.instance_eval do
                    @documents[index][key] = ct
                  end
                  
                end
                
              end
              
            end
            
          end
          
        end
        
        ap args.inspect
        
        callback.call(*args, &block) if callback
        
      end
      
      collection = operation.instance_eval { @full_collection_name }
      
      
      # Only encrypt data stored in collections
      if collection && !collection.index('$cmd')
        
        selector = operation.instance_eval { @selector }
        documents = operation.instance_eval { @documents }
        
        if selector
          selector = encrypt_recurse(selector, collection)
          operation.instance_eval { @selector = selector }
        elsif documents
          documents = documents.map { |d| encrypt_recurse(d, collection) }
          operation.instance_eval { @documents = documents }
        else
          raise 'Should not happen'
        end
        
      end
      
      if Threaded.executing? :pipeline
        queue.push [operation, after_query]
      else
        flush([[operation, after_query]])
      end
      
    end

    def encrypt_recurse(selector, collection)

      return unless selector

      selector.each do |key, val|

        ct = if val.is_a?(Hash)
          encrypt_recurse(val, collection)
        else
          
          next if key == '_id'
          encrypt(key.to_s, val, collection)
          
        end
        
        selector[key] = ct

      end
      
      selector

    end
    

    def encrypt(key, val, collection)

      return val unless val.is_a?(String)

      crypto_key = Cryodex.generate_key(collection, key)

      header = 'cryo|' + collection + '|' + key
      cipher = SIV::Cipher.new(crypto_key)
      header + '|det|' + 
      Base64.strict_encode64(cipher.encrypt(val.dup, [])) + '|end'

    end
    
  end
  
end