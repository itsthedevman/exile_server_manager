# frozen_string_literal: true

describe ESM::Connection::Encryption, v2: true do
  let(:different_encryption) { described_class.new("This is a complete different key not the same at all") }

  let(:key) { "This is the super secret key that is used to encrypt" }

  subject!(:encryption) { described_class.new(key) }

  describe "#encrypt" do
    context "when text is provided" do
      it "returns the encrypted text" do
        encrypted_text = encryption.encrypt("Hello world!")

        expect { encryption.decrypt(encrypted_text) }.not_to raise_error

        # It should also fail decryption with another key
        expect {
          different_encryption.decrypt(encrypted_text)
        }.to raise_error(ESM::Exception::DecryptionError)
      end
    end
  end

  describe "#decrypt" do
    context "when the provided text does not include the correct nonce" do
      it "raises an exception" do
        encrypted_text = encryption.encrypt("Hello world")

        # Same key, different indices
        encryption = described_class.new(
          key,
          nonce_indices: (1...described_class::NONCE_SIZE).to_a
        )

        expect {
          encryption.decrypt(encrypted_text)
        }.to raise_error(ESM::Exception::DecryptionError)
      end
    end

    context "when the provided text was not encrypted with the same key" do
      it "raises an exception" do
        encrypted_text = encryption.encrypt("Hello world")

        expect {
          different_encryption.decrypt(encrypted_text)
        }.to raise_error(ESM::Exception::DecryptionError)
      end
    end

    context "when the provided text was encrypted and encoded correctly" do
      it "returns the decoded and decrypted text" do
        encrypted_text = encryption.encrypt("Hello world")
        decrypted_text = encryption.decrypt(encrypted_text)
        expect(decrypted_text).to eq("Hello world")
      end
    end
  end
end
