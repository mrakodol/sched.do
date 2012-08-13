require 'spec_helper'

describe User, 'validations' do
  it { should have_many(:events) }
  it { should have_many(:user_votes) }
  it { should have_many(:votes).through(:user_votes) }
  it { should have_many(:invitations) }

  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:yammer_user_id) }
  it { should validate_presence_of(:encrypted_access_token) }

  context 'encrypted_access_token' do
    it 'encrypts access_token before validation on create' do
      access_token = 'abc123'
      expected_encrypted_access_token =
        Encryptor.encrypt(access_token, key: ENV['ACCESS_TOKEN_ENCRYPTION_KEY'])
      expected_encrypted_access_token =
        Base64.encode64(expected_encrypted_access_token)
      user = build(:user, access_token: access_token)

      user.save
      user.encrypted_access_token.should == expected_encrypted_access_token
    end
  end
end

describe User, '.find_or_create_with_access_token_and_yammer_user_id' do
  it 'finds a user if one already exists using the yammer_user_id' do
    user = create(:user)
    sent_access_token = 'ZZZZZZZ'

    found_user = User.find_or_create_with_auth( {
      access_token: sent_access_token,
      yammer_staging: user.yammer_staging?,
      yammer_user_id: user.yammer_user_id
    } )

    found_user.should == user
    found_user.access_token.should == sent_access_token
  end

  it 'creates a new user if one does not exist' do
    new_yammer_user_id = 321123
    access_token = 'PUH98h'
    yammer_staging = false
    User.count.should == 0

    User.find_or_create_with_auth(
      access_token: access_token,
      yammer_staging: yammer_staging,
      yammer_user_id: new_yammer_user_id
    )

    user = User.last
    User.count.should == 1
    user.yammer_user_id.should == new_yammer_user_id
    user.access_token.should == access_token
    user.yammer_staging.should == yammer_staging
  end
end

describe User, '#in_network?' do
  it 'returns true if user is in network' do
    user = build_stubbed(:user, yammer_network_id: 1)
    in_network_user = build_stubbed(:user, yammer_network_id: 1)

    user.should be_in_network(in_network_user)
  end
  it 'returns false if user is out network' do
    user = build_stubbed(:user, yammer_network_id: 1)
    in_network_user = build_stubbed(:user, yammer_network_id: 2)

    user.should_not be_in_network(in_network_user)
  end

end

describe User, '#able_to_edit?' do
  it 'returns true if the user created the event' do
    event = create(:event)
    user = event.user
    event.user.should be_able_to_edit(event)
  end

  it 'returns false if the user did not create the event' do
    event = create(:event)
    build(:user).should_not be_able_to_edit(event)
  end
end

describe User, '#image' do
  it 'returns the placeholder if there is no image' do
    user = build_stubbed(:user, image: nil)

    user.image.should == 'http://' + ENV['HOSTNAME'] + '/assets/no_photo.png'
  end

  it 'returns the absolute image url if one exists' do
    user = create(:user)

    user.image.should include('http://www.yammer.com/mugshot/48x48/')
  end
end

describe User, '#vote_for_suggestion' do
  it "returns the user's vote for the given suggestion if the user has one" do
    user = create(:user)
    vote = create(:vote_by_user, user: user)
    user.vote_for_suggestion(vote.suggestion).should == vote
  end

  it 'returns nil if the user has not voted on the suggestion' do
    user = create(:user)
    suggestion = create(:suggestion)
    user.vote_for_suggestion(suggestion).should be_nil
  end
end

describe User, '#voted_for?' do
  it "returns true if the user voted for the suggestion" do
    user = create(:user)
    vote = create(:vote_by_user, user: user)
    user.voted_for?(vote.suggestion).should be_true
  end

  it "returns false if the user did not vote for the suggestion" do
    user = create(:user)
    suggestion = create(:suggestion)
    user.voted_for?(suggestion).should be_false
  end
end

describe User, '#guest?' do
  it 'always returns false' do
    build(:user).should_not be_guest
  end
end

describe User, '#fetch_yammer_user_data' do
  it 'should query the Yammer Users API for Yammer Production data' do
    user = User.new(yammer_user_id: 123456,
                    access_token: 'Tokenz',
                    yammer_staging: false)
    oauth_hash = user.yammer_user_data
    before_user_id = user.yammer_user_id

    user.fetch_yammer_user_data

    before_user_id.should == user.yammer_user_id
    user.yammer_staging?.should == false
    user.email.should == oauth_hash['contact']['email_addresses'].
      first['address']
    user.image.should == oauth_hash['mugshot_url']
    user.name.should == oauth_hash['full_name']
    user.nickname.should == oauth_hash['name']
    user.yammer_profile_url.should == oauth_hash['web_url']
    user.yammer_network_id.should == oauth_hash['network_id']
    user.extra.should == oauth_hash
  end
end

describe User, '#yammer_user?' do
  it 'always returns true' do
    build(:user).should be_yammer_user
  end
end

describe User, '#yammer_endpoint' do
  it 'returns the Yammer staging url if the user is a Yammer staging user' do
    user = create(:user, yammer_staging: true)
    user.yammer_endpoint.should == "https://www.staging.yammer.com/"
  end

  it 'returns the Yammer base url if the user is a Yammer user' do
    user = create(:user)
    user.yammer_endpoint.should == "https://www.yammer.com/"
  end
end


describe User, '#build_user_vote' do
  it 'returns a new UserVote instance with the correct user_id' do
    user = create(:user)
    user_vote = user.build_user_vote
    user_vote.user_id.should == user.id
  end
end

describe User, '#create_yammer_activity' do
  it 'creates a Yammer activity story' do
    FakeYammer.activity_endpoint_hits.should == 0
    user = build_stubbed(:user)
    event = build_stubbed(:event)
    event.generate_uuid

    user.create_yammer_activity('update', event)

    FakeYammer.activity_endpoint_hits.should == 1
  end
end

describe User, '#notify' do
  it 'if the user is out-network, it sends an email notification' do
    invitee = build_stubbed(:out_network_user)
    invitation = build_stubbed(:invitation_with_user,
                               invitee: invitee)
    mailer = stub('mailer', deliver: true)
    UserMailer.stubs(invitation: mailer)
    organizer = invitation.sender

    invitee.notify(invitation)

    organizer.in_network?(invitee).should be_false
    UserMailer.should have_received(:invitation).with(invitee, invitation.event)
    mailer.should have_received(:deliver).once
  end

  it 'if the user is in-network, it sends a private message notification' do
    invitee = build_stubbed(:user)
    invitation = build_stubbed(:invitation_with_user,
                               invitee: invitee)
    organizer = invitation.sender

    invitee.notify(invitation)

    organizer.in_network?(invitee).should be_true
    FakeYammer.messages_endpoint_hits.should == 1
    FakeYammer.message.should include(invitation.event.name)
  end
end
