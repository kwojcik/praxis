require 'spec_helper'

describe Praxis::Mapper::Resource do
  let(:parent_record) { ParentModel.new(id: 100, name: 'george sr') }
  let(:parent_records) { [ParentModel.new(id: 101, name: "georgia"),ParentModel.new(id: 102, name: 'georgina')] }
  let(:record) { SimpleModel.new(id: 103, name: 'george xvi') }
  let(:model) { SimpleModel}

  context 'configuration' do
    subject(:resource) { SimpleResource }
    its(:model) { should == model }

    context 'properties' do
      subject(:properties) { resource.properties }

      it 'includes directly-set properties' do
        expect(properties[:other_resource]).to eq(dependencies: [:other_model])
      end

      it 'inherits from a superclass' do
        expect(properties[:href]).to eq(dependencies: [:id])
      end

      it 'properly overrides a property from the parent' do
        expect(properties[:name]).to eq(dependencies: [:simple_name])
      end
    end
  end

  context 'retrieving resources' do
    context 'getting a single resource' do
      before do
       expect(SimpleModel).to receive(:get).with(name: 'george xvi').and_return(record)
      end

      subject(:resource)  { SimpleResource.get(:name => 'george xvi') }

      it { is_expected.to be_kind_of(SimpleResource) }

      its(:record) { should be record }
    end

    context 'getting multiple resources' do
      before do
        expect(SimpleModel).to receive(:all).with(name: ['george xvi']).and_return([record])
      end

      subject(:resource_collection) { SimpleResource.all(:name => ["george xvi"]) }

      it { is_expected.to be_kind_of(Array) }

      it 'fetches the models and wraps them' do
        resource = resource_collection.first
        expect(resource).to be_kind_of(SimpleResource)
        expect(resource.record).to eq record
      end
    end
  end

  context 'delegating to the underlying model' do

    subject { SimpleResource.new(record) }

    it 'does respond_to attributes in the model' do
      expect(subject).to respond_to(:name)
    end

    it 'does not respond_to :id if the model does not have it' do
      resource = OtherResource.new(OtherModel.new(:name => "foo"))
      expect(resource).not_to respond_to(:id)
    end

    it 'returns raw results for simple attributes' do
      expect(record).to receive(:name).and_call_original
      expect(subject.name).to eq("george xvi")
    end

    it 'wraps model objects in Resource instances' do
      expect(record).to receive(:parent).and_return(parent_record)

      parent = subject.parent

      expect(parent).to be_kind_of(ParentResource)
      expect(parent.name).to eq("george sr")
      expect(parent.record).to eq(parent_record)
    end

    context "for serialized array associations" do
      let(:record) { YamlArrayModel.new(:id => 1)}

      subject { YamlArrayResource.new(record)}

      it 'wraps arrays of model objects in an array of resource instances' do
        expect(record).to receive(:parents).and_return(parent_records)

        parents = subject.parents
        expect(parents).to have(parent_records.size).items
        expect(parents).to be_kind_of(Array)

        parents.each { |parent| expect(parent).to be_kind_of(ParentResource) }
        expect(parents.collect { |parent| parent.record }).to match_array(parent_records)
      end
    end
  end

  context 'resource_delegate' do
    let(:other_name) { "foo" }
    let(:other_attribute) { "other value" }
    let(:other_record) { OtherModel.new(:name => other_name, :other_attribute => other_attribute)}
    let(:other_resource) { OtherResource.new(other_record) }

    let(:record) { SimpleModel.new(id: 105, name: "george xvi", other_name: other_name) }

    subject(:resource) { SimpleResource.new(record) }
    
    it 'delegates to the target' do
      expect(record).to receive(:other_model).and_return(other_record)
      expect(resource.other_attribute).to eq(other_attribute)
    end
  end


  context "memoized resource creation" do
    let(:other_name) { "foo" }
    let(:other_attribute) { "other value" }
    let(:other_record) { OtherModel.new(:name => other_name, :other_attribute => other_attribute)}
    let(:other_resource) { OtherResource.new(other_record) }
    let(:record) { SimpleModel.new(id: 105, name: "george xvi", other_name: other_name) }

    subject(:resource) { SimpleResource.new(record) }

    it 'memoizes related resource creation' do
      allow(record).to receive(:other_model).and_return(other_record)
      expect(resource.other_resource).to be(SimpleResource.new(record).other_resource)
    end

  end


  context ".wrap" do
    it 'memoizes resource creation' do
      expect(SimpleResource.wrap(record)).to be(SimpleResource.wrap(record))
    end

    it 'works with nil resources, returning an empty set' do
      wrapped_obj = SimpleResource.wrap(nil)
      expect(wrapped_obj).to be_kind_of(Array)
      expect(wrapped_obj.length).to be(0)
    end

    it 'works array with nil member, returning only existing records' do
      wrapped_set = SimpleResource.wrap([nil, record])
      expect(wrapped_set).to be_kind_of(Array)
      expect(wrapped_set.length).to be(1)
    end
    
    it 'works with non-enumerable objects, that respond to collect' do
      collectable = double("ArrayProxy", to_a: [record, record] )

      wrapped_set = SimpleResource.wrap(collectable)
      expect(wrapped_set.length).to be(2)
    end

    it 'works regardless of the resource class used' do
      expect(SimpleResource.wrap(record)).to be(OtherResource.wrap(record))
    end
  end

end