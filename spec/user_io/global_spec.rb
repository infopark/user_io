# frozen_string_literal: true

class GlobalTest
  include ::Infopark::UserIO::Global
end

RSpec.describe(Infopark::UserIO::Global) do
  subject(:global_included) { GlobalTest.new }

  let(:user_io) { ::Infopark::UserIO.new }

  around do |example|
    ::Infopark::UserIO.global = user_io
    example.run
    ::Infopark::UserIO.global = nil
  end

  it "provides convenience access to UserIO.global" do
    expect(global_included.user_io).to(be(user_io))
  end
end
