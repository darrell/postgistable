require "spec_helper"


describe Sequel::Model do
  it "does not automatically load postgis extension" do
    expect { Sequel::Model.postgis_extension_loaded? }.to raise_error
  end

  it "will properly load postgis extension" do
    Sequel::Model.plugin :postgis
    Sequel::Model.postgis_extension_loaded?.should be_true
  end
end
    