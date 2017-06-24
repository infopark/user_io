RSpec.describe ::Infopark::UserIO do
  let(:options) { {} }

  subject(:user_io) { ::Infopark::UserIO.new(**options) }

  before do
    allow($stdout).to receive(:puts)
    allow($stdout).to receive(:write)
    allow($stdin).to receive(:gets).and_return("yes\n")
  end

  describe "#ask" do
    let(:ask_options) { {} }
    let(:question) { "do you want to?" }

    subject(:ask) { user_io.ask(*Array(question), **ask_options) }

    shared_examples_for "any question" do
      #it_behaves_like "handling valid answer"
      #it_behaves_like "handling invalid input"
      #it_behaves_like "printing prefix on every line"
    end

    context "with default" do
      let(:ask_options) { {default: default_value} }

      context "“true”" do
        let(:default_value) { true }

        it "presents default answer “yes”" do
          expect($stdout).to receive(:write).with("(yes/no) [yes] >")
          ask
        end

        it "returns “true” on empty input" do
          expect($stdin).to receive(:gets).and_return("\n")
          expect(ask).to be true
        end

        it_behaves_like "any question"
      end

      context "“false”" do
        let(:default_value) { false }

        it "presents default answer “no”" do
          expect($stdout).to receive(:write).with("(yes/no) [no] >")
          ask
        end

        it "returns “false” on empty input" do
          expect($stdin).to receive(:gets).and_return("\n")
          expect(ask).to be false
        end

        it_behaves_like "any question"
      end

      context "non boolean" do
        # TODO
      end
    end
  end
end
