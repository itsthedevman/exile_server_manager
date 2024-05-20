# frozen_string_literal: true

module ESM
  module Connection
    class Encryption
      CIPHER = "aes-256-cbc"

      NONCE_SIZE = 16

      # First 32 bytes.
      # A standard request will larger than 32 bytes so this _shouldn't_ cause issues with the nonce being stacked at the end of the bytes (because of the data packet being smaller than 32 bytes)
      INDEX_LOW_BOUNDS = 0
      INDEX_HIGH_BOUNDS = 31

      def self.generate_nonce_indices
        indices = (INDEX_LOW_BOUNDS...INDEX_HIGH_BOUNDS).to_a.shuffle.shuffle
        NONCE_SIZE.times.map { indices.pop }.sort
      end

      def initialize(key, nonce_indices: [])
        key = key.bytes[INDEX_LOW_BOUNDS..INDEX_HIGH_BOUNDS]
        raise ArgumentError, "Encryption key must be 32 bytes" if key.size != 32

        @key = key.pack("C*")
        @nonce_indices = nonce_indices.presence || (0...NONCE_SIZE).to_a
      end

      def encrypt(data)
        cipher = OpenSSL::Cipher.new(CIPHER).encrypt
        nonce = cipher.random_iv

        cipher.key = @key
        cipher.iv = nonce

        nonce_bytes = nonce.bytes
        encrypted_data = (cipher.update(data) + cipher.final).bytes

        @nonce_indices.each_with_index do |nonce_index, index|
          encrypted_data.insert(nonce_index, nonce_bytes[index])
        end

        # If the nonce index is greater than the size of the encrypted_bytes,
        # ruby will add `nil` until it gets to the index
        encrypted_data.compact.pack("C*")
      end

      #
      # Attempts to decrypt the provided byte array
      #
      # @param input [String] A UTF-8 string containing encrypted data
      #
      # @return [String] The decoded string
      #
      # @raises DecryptionError
      # @raises InvalidSecretKey
      # @raises InvalidNonce
      #
      def decrypt(input)
        cipher = OpenSSL::Cipher.new(CIPHER).decrypt

        nonce = []
        packet = []
        input.bytes.each_with_index do |byte, index|
          if @nonce_indices[nonce.size] == index
            nonce << byte
            next
          end

          packet << byte
        end

        cipher.key = @key
        cipher.iv = nonce.pack("C*")

        decrypted_data = cipher.update(packet.pack("C*")) + cipher.final
        raise ESM::Exception::DecryptionError if decrypted_data.blank?

        decrypted_data
      rescue ArgumentError => e
        case e.message
        when "key must be 32 bytes"
          raise ESM::Exception::DecryptionError, "Invalid secret key length"
        when "iv must be #{NONCE_SIZE} bytes"
          raise ESM::Exception::DecryptionError, "Invalid IV length"
        else
          raise e
        end
      rescue OpenSSL::Cipher::CipherError
        raise ESM::Exception::DecryptionError, "Failed to decrypt"
      end
    end
  end
end
