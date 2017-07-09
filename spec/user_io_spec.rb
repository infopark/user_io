RSpec.describe ::Infopark::UserIO do
  let(:options) { {} }

  subject(:user_io) { ::Infopark::UserIO.new(**options) }

  before do
    allow($stdout).to receive(:puts)
    # for debugging: .and_call_original
    allow($stdout).to receive(:write)
    # for debugging: .and_call_original
  end

  describe ".global" do
    subject(:global) { ::Infopark::UserIO.global }

    it { is_expected.to be_nil }
  end

  describe ".global=" do
    subject(:assign_global) { ::Infopark::UserIO.global = user_io }

    it "assigns the global UserIO" do
      expect {
        assign_global
      }.to change {
        ::Infopark::UserIO.global
      }.to(user_io)
    end
  end

  describe "#acknowledge" do
    before { allow($stdin).to receive(:gets).and_return("\n") }

    let(:message) { "Some important statement." }

    subject(:acknowledge) { user_io.acknowledge(message) }

    it "presents the message (colorized)" do
      expect($stdout).to receive(:write).with("\e[1;36m""Some important statement.""\e[22;39m\n")
      acknowledge
    end

    it "asks for pressing “Enter”" do
      expect($stdout).to receive(:write).with("Please press ENTER to continue.\n")
      acknowledge
    end

    it "requests input" do
      expect($stdin).to receive(:gets).and_return("\n")
      acknowledge
    end
  end

  describe "#ask" do
    before { allow($stdin).to receive(:gets).and_return("yes\n") }

    let(:ask_options) { {} }
    let(:question) { "do you want to?" }

    subject(:ask) { user_io.ask(*Array(question), **ask_options) }

    shared_examples_for "any question" do
      # TODO
      #it_behaves_like "handling valid answer"
      #it_behaves_like "handling invalid input"
      #it_behaves_like "printing prefix on every line"
    end

    context "with default" do
      let(:ask_options) { {default: default_value} }

      context "“true”" do
        let(:default_value) { true }

        it "presents default answer “yes”" do
          expect($stdout).to receive(:write).with("(yes/no) [yes] > ")
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
          expect($stdout).to receive(:write).with("(yes/no) [no] > ")
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

  describe "#select" do
    before { allow($stdin).to receive(:gets).and_return("1\n") }

    let(:description) { "a thing" }
    let(:items) { [:a, :b, :c] }
    let(:select_options) { {} }

    subject(:select) { user_io.select(description, items, **select_options) }

    context "with default" do
      let(:select_options) { {default: :b} }

      it "presents the default's index as default answer" do
        expect($stdout).to receive(:write).with("Your choice [2] > ")
        select
      end

      it "returns the default on empty input" do
        expect($stdin).to receive(:gets).and_return("\n")
        expect(select).to eq(:b)
      end
    end
  end
end
