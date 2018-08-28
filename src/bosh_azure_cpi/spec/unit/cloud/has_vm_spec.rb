# frozen_string_literal: true

require 'spec_helper'
require 'unit/cloud/shared_stuff.rb'

describe Bosh::AzureCloud::Cloud do
  include_context 'shared stuff'

  describe '#has_vm?' do
    let(:instance) { double('instance') }

    before do
      allow(Bosh::AzureCloud::InstanceIdParser).to receive(:parse)
        .with(instance_id, azure_config.resource_group_name)
        .and_return(instance_id_object)

      allow(telemetry_manager).to receive(:monitor)
        .with('has_vm?', id: instance_id).and_call_original
    end

    context 'when the instance exists' do
      before do
        allow(vm_manager).to receive(:find).with(instance_id_object)
                                           .and_return(instance)
        allow(instance).to receive(:[]).with(:provisioning_state)
                                       .and_return('Running')
      end

      it 'should return true' do
        expect(cloud.has_vm?(instance_id)).to be(true)
      end
    end

    context "when the instance doesn't exists" do
      before do
        allow(vm_manager).to receive(:find).with(instance_id_object).and_return(nil)
      end

      it 'should return false' do
        expect(cloud.has_vm?(instance_id)).to be(false)
      end
    end

    context 'when the instance state is Deleting' do
      before do
        allow(vm_manager).to receive(:find).with(instance_id_object)
                                           .and_return(instance)
        allow(instance).to receive(:[]).with(:provisioning_state)
                                       .and_return('Deleting')
      end

      it 'should return false' do
        expect(cloud.has_vm?(instance_id)).to be(false)
      end
    end
  end
end
