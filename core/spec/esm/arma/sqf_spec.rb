# frozen_string_literal: true

RSpec.describe ESM::Arma::Sqf do
  describe ".strip_comments" do
    subject(:stripped) { described_class.strip_comments(code) }

    context "when the code has no comments" do
      let(:code) { "private _x = 1 + 1; _x" }

      it "returns it untouched" do
        expect(stripped).to eq(code)
      end
    end

    context "when the code is empty" do
      let(:code) { "" }

      it "returns it untouched" do
        expect(stripped).to eq("")
      end
    end

    context "when a line comment is on its own line" do
      let(:code) { "// a comment\n1 + 1" }

      it "removes the comment and keeps the newline" do
        expect(stripped).to eq("\n1 + 1")
      end
    end

    context "when a line comment trails code" do
      let(:code) { "private _x = 1 + 1; // the result\n_x" }

      it "removes the comment and keeps the code" do
        expect(stripped).to eq("private _x = 1 + 1; \n_x")
      end
    end

    context "when a line comment ends the source without a newline" do
      let(:code) { "1 + 1 // trailing" }

      it "removes the comment" do
        expect(stripped).to eq("1 + 1 ")
      end
    end

    context "when a block comment is inline" do
      let(:code) { "/* a comment */ 1 + 1" }

      it "removes the comment" do
        expect(stripped).to eq(" 1 + 1")
      end
    end

    context "when a block comment spans lines" do
      let(:code) { "private _x = 1;\n/* one\ntwo\nthree */\n_x" }

      it "replaces it with the lines it spanned so error line numbers still line up" do
        expect(stripped).to eq("private _x = 1;\n\n\n\n_x")
      end
    end

    context "when a block comment is never closed" do
      let(:code) { "1 + 1 /* forever" }

      it "drops the rest of the source" do
        expect(stripped).to eq("1 + 1 ")
      end
    end

    context "when a comment marker sits inside a double quoted string" do
      let(:code) { 'private _url = "http://esmbot.com"; _url' }

      it "leaves the string alone" do
        expect(stripped).to eq(code)
      end
    end

    context "when a block comment marker sits inside a string" do
      let(:code) { 'private _x = "/* not a comment */"; _x' }

      it "leaves the string alone" do
        expect(stripped).to eq(code)
      end
    end

    context "when a comment marker sits inside a single quoted string" do
      let(:code) { "private _x = 'it // stays'; _x" }

      it "leaves the string alone" do
        expect(stripped).to eq(code)
      end
    end

    context "when a string escapes a quote by doubling it" do
      let(:code) { 'private _x = "he said ""hi"" // not a comment"; _x' }

      it "does not mistake the escape for the end of the string" do
        expect(stripped).to eq(code)
      end
    end

    context "when a real comment follows a string containing a quote escape" do
      let(:code) { 'private _x = "say ""hi"""; // a comment' + "\n_x" }

      it "keeps the string and removes the comment" do
        expect(stripped).to eq('private _x = "say ""hi"""; ' + "\n_x")
      end
    end

    context "when a string is never closed" do
      let(:code) { 'private _x = "unterminated // still a string' }

      it "leaves it alone rather than inventing a different syntax error" do
        expect(stripped).to eq(code)
      end
    end

    context "when a single quoted string sits inside a double quoted one" do
      let(:code) { %(private _x = "it's fine // really"; _x) }

      it "does not treat the apostrophe as opening a string" do
        expect(stripped).to eq(code)
      end
    end

    context "when the code has both comment styles and strings" do
      let(:code) do
        <<~SQF
          // leading comment
          private _url = "http://esmbot.com"; /* inline */ private _y = 2;
          _y // trailing
        SQF
      end

      it "removes every comment and keeps every string" do
        expect(stripped).to eq(
          "\nprivate _url = \"http://esmbot.com\";  private _y = 2;\n_y \n"
        )
      end
    end
  end
end
