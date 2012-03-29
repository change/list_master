require 'spec_helper'

describe ListMaster do

  describe '.redis' do

    subject { ListMaster.redis }

    it { should be_an_instance_of Redis::Namespace }

    it "should be connected" do
      subject.client.should be_connected
    end

  end

end
