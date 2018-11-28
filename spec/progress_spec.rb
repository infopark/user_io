module Infopark

RSpec.describe UserIO::Progress do
  COLOR_BRIGHT_GREEN = "\e[1;32m"
  COLOR_NORMAL = "\e[22;39m"

  let(:user_io) { UserIO.new }

  subject(:progress) { UserIO::Progress.new("the label", user_io) }

  before { allow($stdout).to receive(:write) }

  describe "#start" do
    subject(:start) { progress.start }

    it "starts the progress" do
      expect($stdout).to receive(:write).with("the label ")
      start
    end

    context "if already started" do
      before { progress.start }

      it "does nothing" do
        expect($stdout).to_not receive(:write)
        start
      end
    end
  end

  describe "#increment" do
    subject(:increment) { progress.increment }

    context "on a started progress" do
      before { progress.start }

      it "increments" do
        expect($stdout).to receive(:write).with(".")
        increment
      end
    end

    context "on a not started progress" do
      it "fails" do
        expect { increment }.to raise_error(/not started/)
      end
    end

    context "on a finished progress" do
      before do
        progress.start
        progress.finish
      end

      it "fails" do
        expect { increment }.to raise_error(/not started/)
      end
    end
  end

  describe "#spin" do
    subject(:spin) { progress.spin }


    context "on a started progress" do
      before { progress.start }

      it "spins" do
        expect($stdout).to receive(:write).with("-\b").ordered
        progress.spin
        expect($stdout).to receive(:write).with("\\\b").ordered
        progress.spin
        expect($stdout).to receive(:write).with("|\b").ordered
        progress.spin
        expect($stdout).to receive(:write).with("/\b").ordered
        progress.spin
        expect($stdout).to receive(:write).with("-\b").ordered
        progress.spin
        expect($stdout).to receive(:write).with("\\\b").ordered
        progress.spin
        expect($stdout).to receive(:write).with("|\b").ordered
        progress.spin
        expect($stdout).to receive(:write).with("/\b").ordered
        progress.spin
      end

      it "starts spinning from begin when interrupted by an increment" do
        expect($stdout).to receive(:write).with("-\b").ordered
        progress.spin
        expect($stdout).to receive(:write).with("\\\b").ordered
        progress.spin
        expect($stdout).to receive(:write).with(".").ordered
        progress.increment
        expect($stdout).to receive(:write).with("-\b").ordered
        progress.spin
        expect($stdout).to receive(:write).with("\\\b").ordered
        progress.spin
        expect($stdout).to receive(:write).with("|\b").ordered
        progress.spin
        expect($stdout).to receive(:write).with("/\b").ordered
        progress.spin
      end
    end

    context "on a not started progress" do
      it "fails" do
        expect { spin }.to raise_error(/not started/)
      end
    end

    context "on a finished progress" do
      before do
        progress.start
        progress.finish
      end

      it "fails" do
        expect { spin }.to raise_error(/not started/)
      end
    end
  end

  describe "#finish" do
    subject(:finish) { progress.finish }

    context "on a started progress" do
      before { progress.start }

      it "finishes" do
        expect($stdout).to receive(:write).with("… ")
        expect($stdout).to receive(:write).with("#{COLOR_BRIGHT_GREEN}OK#{COLOR_NORMAL}\n")
        finish
      end
    end

    context "on a not started progress" do
      it "does nothing" do
        expect($stdout).to_not receive(:write)
        finish
      end
    end

    context "on a finished progress" do
      before do
        progress.start
        progress.finish
      end

      it "does nothing" do
        expect($stdout).to_not receive(:write)
        finish
      end
    end
  end
end

end
