require 'rails_helper'
require 'support/brady_bunch'

RSpec.describe Api::V1::MobileApiController, dbclean: :after_each do

 describe "get employers_list" do
    let!(:broker_role) {FactoryGirl.create(:broker_role)}
    let(:person) {double("person", broker_role: broker_role, first_name: "Brunhilde")}
    let(:user) { double("user", :has_hbx_staff_role? => false, :has_employer_staff_role? => false, :person => person)}
    let(:organization) {
      o = FactoryGirl.create(:employer)
      a = o.primary_office_location.address
      a.address_1 = '500 Employers-Api Avenue'
      a.address_2 = '#555'
      a.city = 'Washington'
      a.state = 'DC'
      a.zip = '20001'
      o.primary_office_location.phone = Phone.new(:kind => 'main', :area_code => '202', :number => '555-9999')
      o.save
      o
    }
    let(:broker_agency_profile) { 
    	profile = FactoryGirl.create(:broker_agency_profile, organization: organization) 
    	broker_role.broker_agency_profile_id = profile.id
    	profile
    }

    let(:staff_user) { FactoryGirl.create(:user) }
    let(:staff) do
      s = FactoryGirl.create(:person, :with_work_email, :male)
      s.user = staff_user
      s.first_name = "Seymour"
      s.emails.clear
      s.emails << ::Email.new(:kind => 'work', :address => 'seymour@example.com')
      s.phones << ::Phone.new(:kind => 'mobile', :area_code => '202', :number => '555-0000')
      s.save
      s
    end

    let(:staff_user2) { FactoryGirl.create(:user) }
    let(:staff2) do
      s = FactoryGirl.create(:person, :with_work_email, :male)
      s.user = staff_user2
      s.first_name = "Beatrice"
      s.emails.clear
      s.emails << ::Email.new(:kind => 'work', :address => 'beatrice@example.com')
      s.phones << ::Phone.new(:kind => 'work', :area_code => '202', :number => '555-0001')
      s.phones << ::Phone.new(:kind => 'mobile', :area_code => '202', :number => '555-0002')
      s.save
      s
    end

    let (:broker_agency_account) { 
    	FactoryGirl.build(:broker_agency_account, broker_agency_profile: broker_agency_profile) 
    }
    let (:employer_profile) do 
      e = FactoryGirl.create(:employer_profile, organization: organization) 
      e.broker_agency_accounts << broker_agency_account 
      e.save   
      e
    end
    
    before(:each) do 
      allow(user).to receive(:has_hbx_staff_role?).and_return(false)
      allow(user).to receive(:has_broker_agency_staff_role?).and_return(false)
      sign_in(user)
    end

    it "should get summaries for employers where broker_agency_account is active" do
      
      #TODO tests for open_enrollment_start_on, open_enrollment_end_on, start_on, is_renewing?, etc              

      staff.employer_staff_roles << FactoryGirl.create(:employer_staff_role, employer_profile_id: employer_profile.id)
      staff2.employer_staff_roles << FactoryGirl.create(:employer_staff_role, employer_profile_id: employer_profile.id)
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      xhr :get, :employers_list, id: broker_agency_profile.id, format: :json
      expect(response).to have_http_status(:success), "expected status 200, got #{response.status}: \n----\n#{response.body}\n\n"
      details = assigns[:employer_details]
      detail = details[0]
      expect(details.count).to eq 1
      expect(detail[:employer_name]).to eq employer_profile.legal_name
      contacts = detail[:contact_info]

      seymour = contacts.detect  { |c| c[:first] == 'Seymour' }
      beatrice = contacts.detect { |c| c[:first] == 'Beatrice' }
      office = contacts.detect   { |c| c[:first] == 'Primary' }
      expect(seymour[:mobile]).to eq '(202) 555-0000'
      expect(seymour[:phone]).to eq ''
      expect(beatrice[:phone]).to eq '(202) 555-0001'
      expect(beatrice[:mobile]).to eq '(202) 555-0002'
      expect(seymour[:emails]).to include('seymour@example.com')
      expect(beatrice[:emails]).to include('beatrice@example.com')
      expect(office[:phone]).to eq '(202) 555-9999'
      expect(office[:address_1]).to eq '500 Employers-Api Avenue'
      expect(office[:address_2]).to eq '#555'
      expect(office[:city]).to eq 'Washington'
      expect(office[:state]).to eq 'DC'
      expect(office[:zip]).to eq '20001'
   
      output = JSON.parse(response.body)

      expect(output["broker_name"]                  ).to eq("Brunhilde")
      employer = output["broker_clients"][0]
      expect(employer).not_to be(nil), "in #{output}"
      expect(employer["employer_name"]                ).to eq(employer_profile.legal_name)
      expect(employer["employees_total"]              ).to eq(employer_profile.roster_size)   
      expect(employer["employees_enrolled"]           ).to be(nil)
      expect(employer["employees_waived"]             ).to be(nil)
      expect(employer["open_enrollment_begins"]       ).to be(nil)
      expect(employer["open_enrollment_ends"]         ).to be(nil)
      expect(employer["plan_year_begins"]             ).to be(nil)
      expect(employer["renewal_in_progress"]          ).to be(nil)
      expect(employer["renewal_application_available"]).to be(nil)
      expect(employer["renewal_application_due"]      ).to be(nil)
      expect(employer["employer_details_url"]         ).to end_with("mobile_api/employer_details/#{employer_profile.id}")
    end
  end

describe "GET employer_details" do  
  let(:user) { double("user", :person => person) }
  let(:person) { double("person", :employer_staff_roles => [employer_staff_role]) }
  let(:employer_staff_role) { double(:employer_profile_id => employer_profile.id) }
  let(:plan_year) { FactoryGirl.create(:plan_year) }
  let(:employer_profile) { plan_year.employer_profile}

  before(:each) do 
   sign_in(user)
  end

  it "should render 200 with valid ID" do
    get :employer_details, {employer_profile_id: employer_profile.id.to_s}
    expect(response).to have_http_status(200), "expected status 200, got #{response.status}: \n----\n#{response.body}\n\n"
   expect(response.content_type).to eq "application/json"
  end

  it "should render 404 with Invalid ID" do
    get :employer_details, {employer_profile_id: "Invalid Id"}
    expect(response).to have_http_status(404), "expected status 404, got #{response.status}: \n----\n#{response.body}\n\n"
  end

  it "should match with the expected result set" do
    get :employer_details, {employer_profile_id: employer_profile.id.to_s}
    output = JSON.parse(response.body)
    puts "#{employer_profile.inspect}"
    expect(output["employer_name"]).to eq(employer_profile.legal_name)
    expect(output["employees_total"]).to eq(employer_profile.roster_size)
    expect(output["active_general_agency"]).to eq(employer_profile.active_general_agency_legal_name)

    if employer_profile.show_plan_year
      expect(output["employees_waived"]).to eq(employer_profile.show_plan_year.waived_count)
      expect(output["open_enrollment_begins"]).to eq(employer_profile.show_plan_year.open_enrollment_start_on)
      expect(output["open_enrollment_ends"]).to eq(employer_profile.show_plan_year.open_enrollment_end_on) 
      expect(output["plan_year_begins"]).to eq(employer_profile.show_plan_year.start_on) 
      expect(output["renewal_in_progress"]).to eq(employer_profile.show_plan_year.is_renewing?) 
      expect(output["renewal_application_due"]).to eq(employer_profile.show_plan_year.due_date_for_publish) 
      expect(output["minimum_participation_required"]).to eq(employer_profile.show_plan_year. minimum_enrolled_count) 
    end
  end
 end



# **********************************////////////************************************
  context "Functionality and security specs" do 
  include_context "BradyWorkAfterAll"

   before :each do
      create_brady_census_families
  end

  context "Specs for Mike and Carol from BradyBunch" do
    include_context "BradyBunch"  
    attr_reader :mikes_organization, :mikes_employer, :mikes_family, :carols_organization, :carols_employer, :carols_family

let!(:org) { FactoryGirl.create(:organization) }
let!(:broker_agency_profile) { FactoryGirl.create(:broker_agency_profile, organization: org) }
let!(:broker_role) { FactoryGirl.create(:broker_role, broker_agency_profile_id: broker_agency_profile.id) }
let!(:broker_agency_account) { FactoryGirl.create(:broker_agency_account, broker_agency_profile: broker_agency_profile, writing_agent: broker_role, family: mikes_family)}
let!(:mikes_employer) {FactoryGirl.create(:employer_profile, organization: mikes_organization, broker_agency_profile: broker_agency_profile, broker_role_id: broker_role._id, broker_agency_accounts: [broker_agency_account])}
let!(:user) { FactoryGirl.create(:user, person: broker_role.person, roles: [:broker]) }


let!(:org1) { FactoryGirl.create(:organization, legal_name: "Alphabet Agency", dba: "ABCD etc") }
let!(:broker_agency_profile1) { FactoryGirl.create(:broker_agency_profile, organization: org1) }
let!(:broker_role1) { FactoryGirl.create(:broker_role, broker_agency_profile_id: broker_agency_profile1.id) }
let!(:broker_agency_account1) { FactoryGirl.create(:broker_agency_account, broker_agency_profile: broker_agency_profile1, writing_agent: broker_role1, family: carols_family)}
let!(:person) { broker_role1.person.tap do |person| 
                      person.first_name = "Walter" 
                      person.last_name = "White"
                      end
                      broker_role1.person.save
                      broker_role1.person 
                    }

let!(:user1) { FactoryGirl.create(:user, person: broker_role1.person, roles: [:broker]) }
let!(:carols_emp) { carols_employer.tap do |carol| 
                                carol.organization = carols_organization
                                carol.broker_agency_profile = broker_agency_profile1
                                carol.broker_role_id = broker_role1._id
                                carol.broker_agency_accounts = [broker_agency_account1]
                                end
                    carols_employer.save 
                    carols_employer

                           }

let(:hbx_person) { FactoryGirl.create(:person, first_name: "Jessie")}
let!(:hbx_staff_role) { FactoryGirl.create(:hbx_staff_role, person: hbx_person)}
let!(:hbx_user) { double("user", :has_broker_agency_staff_role? => false ,:has_hbx_staff_role? => true, :has_employer_staff_role? => false, :has_broker_role? => false, :person => hbx_staff_role.person) }                          

# what I could really use is extending the brady bunch setup to include brokers
# 3:33 like there's a broker who represents Mike's company and another who represents Carol's
# 3:33 and the brokers belong to different agencies and one is on staff at their agency and the agencies are themselves employers
# 3:35 and we'd have another user who's an hbx admin
# 3:35 so the test cases are:
# 3:36 - the hbx admin should be able to see anything
# 3:36 - the broker for Mike's company should see only Mike's company, not Carol's, in employers_list, and should be able to see the roster/details for Mike's company (but get a 404 or empty list if they follow the link for Carol's)
# 3:40 - Mike's employer should be able to see his own roster & details, but shouldn't be able to access employers_list at all, and also shouldn't be able to see Carol's stuff
context "Mikes specs" do
before(:each) do
  sign_in user
  get :employers_list, id: broker_agency_profile.id, format: :json
  @output = JSON.parse(response.body)
end


it "Mikes broker should be able to login and get success status" do
  expect(@output["broker_name"]).to eq("John")
  expect(response).to have_http_status(:success), "expected status 200, got #{response.status}: \n----\n#{response.body}\n\n"
end

it "No of broker clients in Mikes broker's employer's list should be 1" do
  expect(@output["broker_clients"].count).to eq 1
end


it "Mikes broker should be able to see only Mikes Company and it shouldn't be nil" do
      expect(@output["broker_clients"][0]).not_to be(nil), "in #{@output}"
      expect(@output["broker_clients"][0]["employer_name"]).to eq(mikes_employer.legal_name)
end

it "Mikes broker should be able to access the Mikes employee roster" do
 get :employee_roster, {employer_profile_id: mikes_employer.id.to_s}, format: :json
 @output = JSON.parse(response.body)
 expect(response).to have_http_status(:success)
 expect(@output["employer_name"]).to eq(mikes_employer.legal_name)
 expect(@output["roster"].blank?).to be_truthy
end

it "HBX Admin should be able to see Mikes details" do
  sign_out user
  sign_in hbx_user
  get :employers_list, id: broker_agency_profile.id, format: :json
  @output = JSON.parse(response.body) 
  expect(@output["broker_agency"]).to eq("Turner Agency, Inc")
  expect(@output["broker_clients"].count).to eq 1
  expect(@output["broker_clients"][0]["employer_name"]).to eq(mikes_employer.legal_name)
end

end


context "carols specs" do
before(:each) do
  sign_in user1
  get :employers_list, id: broker_agency_profile1.id, format: :json
  @output = JSON.parse(response.body)
end


it "Carols broker should be able to login and get success status" do
  expect(@output["broker_name"]).to eq("Walter")
  expect(response).to have_http_status(:success), "expected status 200, got #{response.status}: \n----\n#{response.body}\n\n"
end

it "No of broker clients in Carols broker's employer's list should be 1" do
  expect(@output["broker_clients"].count).to eq 1
end


it "Carols broker should be able to see only Mikes Company and it shouldn't be nil" do
      expect(@output["broker_clients"][0]).not_to be(nil), "in #{@output}"
      expect(@output["broker_clients"][0]["employer_name"]).to eq(carols_employer.legal_name)
end


it "Carols broker should be able to access the Carols employee roster" do
 get :employee_roster, {employer_profile_id: carols_employer.id.to_s}, format: :json
 @output = JSON.parse(response.body)
 expect(response).to have_http_status(:success)
 expect(@output["employer_name"]).to eq(carols_employer.legal_name)
 expect(@output["roster"]).not_to be []
 expect(@output["roster"].count).to eq 1
end


it "HBX Admin should be able to see Carols details" do
  sign_in hbx_user
  get :employers_list, id: broker_agency_profile1.id, format: :json
  @output = JSON.parse(response.body) 
  expect(@output["broker_agency"]).to eq("Alphabet Agency")
  expect(@output["broker_clients"].count).to eq 1
  expect(@output["broker_clients"][0]["employer_name"]).to eq(carols_employer.legal_name)
end

end



# it "Carols broker should be able to see only Carols Company" do
# # puts "#{carols_employer.inspect}"
# # carols_employer.organization = carols_organization 
# # carols_employer.save
# puts "*******#{carols_employer.organization.inspect}"
# puts "#{broker_role1.person.inspect}"



#   sign_in user1
#   get :employers_list, id: broker_agency_profile1.id, format: :json
#   output = JSON.parse(response.body)

# puts "#{output.inspect}"
#       expect(response).to have_http_status(:success), "expected status 200, got #{response.status}: \n----\n#{response.body}\n\n"
#       expect(output["broker_name"]).to eq("Walter")
#       employer = output["broker_clients"][0]
#       expect(output["broker_clients"].count).to eq 1
#       expect(employer).not_to be(nil), "in #{output}"
#       expect(employer["employer_name"]).to eq(carols_employer.legal_name)
# end

end
end
end


