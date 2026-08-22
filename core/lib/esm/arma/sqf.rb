# frozen_string_literal: true

require "strscan"

module ESM
  module Arma
    class Sqf
      ##
      # Removes `//` line comments and `/* */` block comments from SQF source.
      #
      # Arma only strips comments in its preprocessor, and every preprocessor command reads from a file. Code sent to
      # `ESMs_command_sqf` is handed to `call compile` as a string, so a comment that reaches the server is a syntax
      # error, and a silent one: the result comes back as nil with the reason left behind in the server's RPT.
      #
      # Comment markers inside string literals are left alone. SQF has no backslash escape - a quote is escaped by
      # doubling it - so the scanner only has to remember which quote character opened the literal.
      #
      # @param code [String] SQF source
      #
      # @return [String] The source with its comments removed, newlines preserved so the line numbers in any
      #   resulting Arma error still point at the right place
      #
      # @example
      #   ESM::Arma::Sqf.strip_comments('private _url = "http://esmbot.com"; // a comment')
      #   #=> 'private _url = "http://esmbot.com"; '
      #
      def self.strip_comments(code)
        return code if code.nil? || code.empty?

        output = +""
        scanner = StringScanner.new(code)

        until scanner.eos?
          if (quote = scanner.scan(/["']/))
            output << quote << scan_string(scanner, quote)
          elsif scanner.scan(%r{//})
            scanner.skip(/[^\n]*/)
          elsif scanner.scan(%r{/\*})
            output << "\n" * skip_block_comment(scanner).count("\n")
          else
            output << scanner.getch
          end
        end

        output
      end

      #
      # Consumes the remainder of a string literal, opening quote already eaten, and returns it verbatim.
      #
      # A doubled quote is SQF's escape, so a quote followed by another quote continues the literal rather than
      # closing it. An unterminated literal swallows the rest of the source, which leaves the caller's syntax error
      # intact instead of inventing a different one.
      #
      def self.scan_string(scanner, quote)
        closing = /#{Regexp.escape(quote)}/
        literal = +""

        loop do
          chunk = scanner.scan_until(closing)

          if chunk.nil?
            literal << scanner.rest
            scanner.terminate
            break
          end

          literal << chunk
          break unless scanner.peek(1) == quote

          literal << scanner.getch
        end

        literal
      end

      #
      # Consumes a block comment, opening `/*` already eaten, and returns its body so the caller can count the
      # newlines it spanned. Block comments do not nest in SQF, so the first `*/` closes it.
      #
      def self.skip_block_comment(scanner)
        body = scanner.scan_until(%r{\*/})
        return body if body

        body = scanner.rest
        scanner.terminate
        body
      end

      private_class_method :scan_string, :skip_block_comment
    end
  end
end
