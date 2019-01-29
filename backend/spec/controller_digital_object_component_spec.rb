require 'spec_helper'

describe 'Digital Object Component controller' do

  it "lets you create an digital object component and get it back" do
    opts = {:title => 'The digital object component title'}

    created = create(:json_digital_object_component, opts).id
    expect(JSONModel(:digital_object_component).find(created).title).to eq(opts[:title])
  end


  it "lets you list all digital object components" do
    create_list(:json_digital_object_component, 5)
    expect(JSONModel(:digital_object_component).all(:page => 1)['results'].count).to eq(5)
  end


  it "lets you create an digital object component with a parent" do
    digital_object = create(:json_digital_object)

    parent = create(:json_digital_object_component, :digital_object => {:ref => digital_object.uri})

    child = create(:json_digital_object_component, {
                     :title => 'Child',
                     :parent => {:ref => parent.uri},
                     :digital_object => {:ref => digital_object.uri}
                   })

    get "#{$repo}/digital_object_components/#{parent.id}/children"
    expect(last_response).to be_ok

    children = JSON(last_response.body)
    expect(children[0]['title']).to eq('Child')
  end


  it "handles updates for an existing digital object component" do
    created = create(:json_digital_object_component)

    opts = {:title => 'A brand new title'}

    doc = JSONModel(:digital_object_component).find(created.id)
    doc.title = opts[:title]
    doc.save

    expect(JSONModel(:digital_object_component).find(created.id).title).to eq(opts[:title])
  end


  it "lets you reorder sibling digital object components" do
    digital_object = create(:json_digital_object)

    doc_1 = create(:json_digital_object_component, :digital_object => {:ref => digital_object.uri}, :title=> "DOC1", :position => 0)
    doc_2 = create(:json_digital_object_component, :digital_object => {:ref => digital_object.uri}, :title=> "DOC2", :position => 1)

    tree = JSONModel(:digital_object_tree).find(nil, :digital_object_id => digital_object.id)

    expect(tree.children[0]["title"]).to eq("DOC1")
    expect(tree.children[1]["title"]).to eq("DOC2")

    doc_1 = JSONModel(:digital_object_component).find(doc_1.id)
    doc_1.position = 1
    doc_1.save

    tree = JSONModel(:digital_object_tree).find(nil, :digital_object_id => digital_object.id)

    expect(tree.children[0]["title"]).to eq("DOC2")
    expect(tree.children[1]["title"]).to eq("DOC1")
  end


  it "supports saving and loading file versions" do
    version = build(:json_file_version)
    digital_object_component = create(:json_digital_object_component,
                                      :file_versions => [version])

    created = JSONModel(:digital_object_component).find(digital_object_component.id)

    expect(created.file_versions.count).to eq(1)
    expect(created.file_versions[0]['file_uri']).to eq(version.file_uri)
  end


  it "accepts move of multiple children" do
    digital_object = create(:json_digital_object)
    target = create(:json_digital_object_component, :digital_object => {:ref => digital_object.uri})

    sibling_1 = create(:json_digital_object_component, :digital_object => {:ref => digital_object.uri})
    sibling_2 = create(:json_digital_object_component, :digital_object => {:ref => digital_object.uri})

    response = JSONModel::HTTP::post_form("#{target.uri}/accept_children", {"children[]" => [sibling_1.uri, sibling_2.uri], "position" => 0})
    json_response = ASUtils.json_parse(response.body)

    expect(json_response["status"]).to eq("Updated")
    get "#{$repo}/digital_object_components/#{target.id}/children"
    expect(last_response).to be_ok

    children = ASUtils.json_parse(last_response.body)

    expect(children.length).to eq(2)
    expect(children[0]["title"]).to eq(sibling_1["title"])
    expect(children[0]["parent"]["ref"]).to eq(target.uri)
    expect(children[0]["digital_object"]["ref"]).to eq(digital_object.uri)

    expect(children[1]["title"]).to eq(sibling_2["title"])
    expect(children[1]["parent"]["ref"]).to eq(target.uri)
    expect(children[1]["digital_object"]["ref"]).to eq(digital_object.uri)
  end


  it "lets you create digital object component with a parent" do
    digital_object = create(:json_digital_object)

    parent = create(:json_digital_object_component, :digital_object => {:ref => digital_object.uri})

    child = create(:json_digital_object_component, {
      :title => 'Child',
      :parent => {:ref => parent.uri},
      :digital_object => {:ref => digital_object.uri}
    })

    get "#{$repo}/digital_object_components/#{parent.id}/children"
    expect(last_response).to be_ok

    children = JSON(last_response.body)
    expect(children[0]['title']).to eq('Child')
  end


  it "allows posting of array of children" do
    digital_object = create(:json_digital_object)
    parent_component = create(:json_digital_object_component, :digital_object => {:ref => digital_object.uri})

    doc_1 = build(:json_digital_object_component, :position => nil )
    doc_2 = build(:json_digital_object_component, :position => nil )

    children = JSONModel(:digital_record_children).from_hash({
                                                                "children" => [doc_1, doc_2]
                                                              })

    url = URI("#{JSONModel::HTTP.backend_url}#{parent_component.uri}/children")
    response = JSONModel::HTTP.post_json(url, children.to_json)
    json_response = ASUtils.json_parse(response.body)

    expect(json_response["status"]).to eq("Updated")
    get "#{$repo}/digital_object_components/#{json_response["id"]}/children"
    expect(last_response).to be_ok

    children = JSON(last_response.body)

    expect(children.length).to eq(2)
    expect(children[0]["title"]).to eq(doc_1["title"])
    expect(children[0]["parent"]["ref"]).to eq(parent_component.uri)
    expect(children[0]["digital_object"]["ref"]).to eq(digital_object.uri)

    expect(children[1]["title"]).to eq(doc_2["title"])
    expect(children[1]["parent"]["ref"]).to eq(parent_component.uri)
    expect(children[1]["digital_object"]["ref"]).to eq(digital_object.uri)
  end


  it "includes the ARK identifier in the digital_object_components JSON" do
    doc = create(:json_digital_object_component)
    uri = JSONModel(:digital_object_component).uri_for(doc.id)

    json = JSONModel::HTTP.get_json(uri)

    expect(json['ark_identifier']).to_not be_nil
    expect(json['ark_identifier']['id']).to_not be_nil
  end


end
