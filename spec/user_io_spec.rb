module Infopark

RSpec.describe UserIO do
  let(:options) { {} }

  subject(:user_io) { UserIO.new(**options) }

  before do
    allow($stdout).to receive(:puts)
    # for debugging: .and_call_original
    allow($stdout).to receive(:write)
    # for debugging: .and_call_original
  end

  describe ".global" do
    subject(:global) { UserIO.global }

    it { is_expected.to be_nil }
  end

  describe ".global=" do
    subject(:assign_global) { UserIO.global = user_io }

    it "assigns the global UserIO" do
      expect {
        assign_global
      }.to change {
        UserIO.global
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

  describe "#tell_error" do
    let(:error) { {my: :error} }
    let(:tell_options) { {} }

    subject(:tell_error) { user_io.tell_error(error, **tell_options) }

    it "tells the given thing in bright red" do
      expect(user_io).to receive(:tell).with(error, color: :red, bright: true)
      tell_error
    end

    context "with options" do
      let(:tell_options) { {newline: false} }

      it "delegates them to #tell" do
        expect(user_io).to receive(:tell).with(error, newline: false, color: :red, bright: true)
        tell_error
      end
    end

    context "when error is a kind of an exception" do
      let(:error) { UserIO::Aborted.new }

      before { allow(error).to receive(:backtrace).and_return(%w(a b c)) }

      it "tells the error and the whole backtrace" do
        expect(user_io).to receive(:tell).with(error, color: :red, bright: true)
        expect(user_io).to receive(:tell).with(%w(a b c), color: :red)
        tell_error
      end
    end
  end

  describe "#tell_pty_stream" do
    let(:color_options) { {} }
    let(:stream) { instance_double(IO) }
    let(:data) { "test data" }

    subject(:tell) { user_io.tell_pty_stream(stream, **color_options) }

    before do
      chunks = Array(data)
      allow(stream).to receive(:eof?).and_return(*[false] * chunks.size, true)
      allow(stream).to receive(:read_nonblock).and_return(*chunks)
      RSpec::Mocks.space.proxy_for($stdout).reset
      allow($stdout).to receive(:write).with(nil)
    end

    it "tells all data from stream in non blocking chunks" do
      expect(stream).to receive(:eof?).and_return(false, false, false, true)
      expect(stream).to receive(:read_nonblock).with(100).
          and_return("first\nchunk", "second chunk", "\nlast chunk")
      expect($stdout).to receive(:write).with("first\nchunk")
      expect($stdout).to receive(:write).with("second chunk")
      expect($stdout).to receive(:write).with("\nlast chunk")
      tell
    end

    context "with color" do
      let(:color_options) { {color: :yellow} }

      it "colorizes the output" do
        expect($stdout).to receive(:write).with("\e[33m").ordered
        expect($stdout).to receive(:write).with("test data").ordered
        expect($stdout).to receive(:write).with("\e[22;39m").ordered
        tell
      end
    end

    context "with output_prefix" do
      let(:options) { {output_prefix: "the prefix"} }

      it "prefixes the output" do
        expect($stdout).to receive(:write).with("[the prefix] ").ordered
        expect($stdout).to receive(:write).with("test data").ordered
        tell
      end

      context "with color" do
        let(:color_options) { {color: :yellow} }

        it "does not colorize the prefix" do
          expect($stdout).to receive(:write).with("[the prefix] ").ordered
          expect($stdout).to receive(:write).with("\e[33m").ordered
          expect($stdout).to receive(:write).with("test data").ordered
          expect($stdout).to receive(:write).with("\e[22;39m").ordered
          tell
        end
      end

      context "when stream contains carriage return" do
        let(:data) { "some\rdata\rwith\rCRs" }

        it "writes the prefix right after the CR" do
          expect($stdout).to receive(:write).with("[the prefix] ").ordered
          expect($stdout).to receive(:write).
              with("some\r[the prefix] data\r[the prefix] with\r[the prefix] CRs").ordered
          tell
        end

        context "with color" do
          let(:color_options) { {color: :yellow} }

          it "uncolorizes the prefix" do
            expect($stdout).to receive(:write).with("[the prefix] ").ordered
            expect($stdout).to receive(:write).with("\e[33m").ordered
            expect($stdout).to receive(:write).with(
              "some\r"\
              "\e[22;39m" "[the prefix] " "\e[33m" "data\r"\
              "\e[22;39m" "[the prefix] " "\e[33m" "with\r"\
              "\e[22;39m" "[the prefix] " "\e[33m" "CRs"
            ).ordered
            expect($stdout).to receive(:write).with("\e[22;39m").ordered
            tell
          end
        end
      end

      context "when stream contains newline" do
        let(:data) { "some\ndata\nwith\nNLs" }

        it "writes the prefix right after the NL" do
          expect($stdout).to receive(:write).with("[the prefix] ").ordered
          expect($stdout).to receive(:write).
              with("some\n[the prefix] data\n[the prefix] with\n[the prefix] NLs")
          tell
        end

        context "with color" do
          let(:color_options) { {color: :yellow} }

          it "uncolorizes the prefix" do
            expect($stdout).to receive(:write).with("[the prefix] ").ordered
            expect($stdout).to receive(:write).with("\e[33m").ordered
            expect($stdout).to receive(:write).with(
              "some\n"\
              "\e[22;39m" "[the prefix] " "\e[33m" "data\n"\
              "\e[22;39m" "[the prefix] " "\e[33m" "with\n"\
              "\e[22;39m" "[the prefix] " "\e[33m" "NLs"
            ).ordered
            expect($stdout).to receive(:write).with("\e[22;39m").ordered
            tell
          end
        end

        context "when stream ends with newline" do
          # includes an empty chunk to verify, that they don't consume the pending NL
          let(:data) { ["some\n", "data\n", "with\n", "", "NLs\n", ""] }

          it "does not write prefix after the last newline" do
            expect($stdout).to receive(:write).with("[the prefix] ").ordered
            expect($stdout).to receive(:write).with("some").ordered
            expect($stdout).to receive(:write).with("\n" "[the prefix] ").ordered
            expect($stdout).to receive(:write).with("data").ordered
            expect($stdout).to receive(:write).with("\n" "[the prefix] ").ordered
            expect($stdout).to receive(:write).with("with").ordered
            expect($stdout).to receive(:write).with("\n" "[the prefix] ").ordered
            expect($stdout).to receive(:write).with("NLs").ordered
            expect($stdout).to receive(:write).with("\n").ordered
            tell
          end

          context "with color" do
            let(:color_options) { {color: :yellow} }

            it "uncolorizes the prefix" do
              expect($stdout).to receive(:write).with("[the prefix] ").ordered
              expect($stdout).to receive(:write).with("\e[33m").ordered
              expect($stdout).to receive(:write).with("some").ordered
              expect($stdout).to receive(:write).
                  with("\n" "\e[22;39m" "[the prefix] " "\e[33m").ordered
              expect($stdout).to receive(:write).with("data").ordered
              expect($stdout).to receive(:write).
                  with("\n" "\e[22;39m" "[the prefix] " "\e[33m").ordered
              expect($stdout).to receive(:write).with("with").ordered
              expect($stdout).to receive(:write).
                  with("\n" "\e[22;39m" "[the prefix] " "\e[33m").ordered
              expect($stdout).to receive(:write).with("NLs").ordered
              expect($stdout).to receive(:write).with("\n").ordered
              expect($stdout).to receive(:write).with("\e[22;39m").ordered
              tell
            end
          end
        end
      end

      context "when data does not end with newline" do
        let(:data) { "foo" }

        it "writes prefix on next output nevertheless" do
          expect($stdout).to receive(:write).with("[the prefix] ").ordered
          expect($stdout).to receive(:write).with("foo").ordered
          tell
          expect($stdout).to receive(:write).with("[the prefix] next\n")
          user_io.tell("next")
        end
      end

      context "when no newline was printed before" do
        before do
          expect($stdout).to receive(:write).with("[the prefix] no newline").ordered
          user_io.tell("no newline", newline: false)
        end

        it "does not prepend prefix" do
          expect($stdout).to receive(:write).with("test data").ordered
          tell
        end

        it "prints prefix on following output" do
          expect($stdout).to receive(:write).with("test data").ordered
          tell
          expect($stdout).to receive(:write).with("[the prefix] next\n")
          user_io.tell("next")
        end
      end
    end

    context "when in background" do
      let(:color_options) { {color: :yellow} }
      let(:options) { {output_prefix: "foo"} }
      let(:data) { ["data\n", "in\nchunks", "", "yo\n", ""] }

      let!(:foreground_thread) do
        @finished = false
        Thread.new do
          user_io.background_other_threads
          sleep 0.1 until @finished
          user_io.foreground
        end
      end

      after { foreground_thread.kill.join }

      it "holds back the output until coming back to foreground" do
        expect($stdout).to_not receive(:write)
        tell
        RSpec::Mocks.space.proxy_for($stdout).reset
        expect($stdout).to receive(:write).with("[foo] ").ordered
        expect($stdout).to receive(:write).with("\e[33m").ordered
        expect($stdout).to receive(:write).with("data").ordered
        expect($stdout).to receive(:write).with("\n" "\e[22;39m" "[foo] " "\e[33m").ordered
        expect($stdout).to receive(:write).
            with("in\n" "\e[22;39m" "[foo] " "\e[33m" "chunks").ordered
        expect($stdout).to receive(:write).with("yo").ordered
        expect($stdout).to receive(:write).with("\n").ordered
        expect($stdout).to receive(:write).with("\e[22;39m").ordered
        @finished = true
        foreground_thread.join
      end
    end
  end
end

end
