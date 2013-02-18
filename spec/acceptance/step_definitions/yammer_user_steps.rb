step 'no sched.do user exists with email :email' do |email|
  expect(User.find_by_email(email)).to be_nil
end

step 'a Yammer user exists named :name with email :email' do |name, email|
  yammer = Yam.new('123', 'https://www.yammer.com/api/v1')
  FakeYammer.yammer_user_name = name
  FakeYammer.yammer_email = email
  users = yammer.get('/users/by_email', email: email)
  expect(users[0]['id']).to be_present
end

step 'no Yammer user exists with email :email' do |email|
  yammer = Yam.new('123', 'https://www.yammer.com/api/v1')
  FakeYammer.yammer_user_name = 'Wrong Name'
  FakeYammer.yammer_email = email + '.fake'
  users = yammer.get('/users/by_email', email: email)
  expect(users.first).to_not be_present
end

step ':email signs up for Yammer as :name' do |email, name|
  yammer = Yam.new('123', 'https://www.yammer.com/api/v1')
  FakeYammer.yammer_user_name = name
  FakeYammer.yammer_email = email
  users = yammer.get('/users/by_email', email: email)
  expect(users[0]['id']).to be_present
end
